/*
 * Paste this entire file into a Chromium DevTools Snippet on usevia.app and run
 * it before the page asks for or opens the keyboard. Then explicitly select the
 * device with webhidTrace.select({ vendorId, productId }). This code never calls
 * requestDevice() and never initiates a HID write.
 *
 * Instrumentation is local to one JavaScript realm. Reloads, new tabs, iframes,
 * and workers have separate globals and require their own installation before
 * HID use. Calls through method references captured before installation cannot
 * be observed. In particular, a page-installed snippet cannot see HID traffic
 * issued inside a worker.
 */
(function installEntry(root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = { installWebHIDTrace: factory };
    return;
  }

  if (root.webhidTrace && root.webhidTrace.__webhidTrace === true) {
    root.webhidTrace.stop();
  }
  root.webhidTrace = factory(root);
  root.console.info(
    "WebHID trace installed. Select a device before capture, for example: " +
      "webhidTrace.select({vendorId: 0x28e9, productId: 0x3145})",
  );
})(typeof globalThis === "object" ? globalThis : window, function installWebHIDTrace(
  root,
  options,
) {
  "use strict";

  const settings = options || {};
  const requestedLimit = Number(settings.maxEntries);
  const maxEntries =
    Number.isSafeInteger(requestedLimit) && requestedLimit > 0
      ? requestedLimit
      : 2_000;
  const entries = [];
  let firstEntry = 0;
  const listeners = new Map();
  const restorers = [];
  let dropped = 0;
  let target = null;
  let active = true;

  function requireUsbId(value, name) {
    if (!Number.isInteger(value) || value < 0 || value > 0xffff) {
      throw new TypeError(`${name} must be an integer from 0 to 65535`);
    }
    return value;
  }

  function deviceIds(device) {
    return {
      vendorId: Number(device.vendorId),
      productId: Number(device.productId),
    };
  }

  function selected(device) {
    if (!active || target === null) return false;
    const ids = deviceIds(device);
    return ids.vendorId === target.vendorId && ids.productId === target.productId;
  }

  function bytesFrom(value) {
    if (value == null) return null;

    if (ArrayBuffer.isView(value)) {
      return Array.from(
        new Uint8Array(value.buffer, value.byteOffset, value.byteLength),
      );
    }

    const tag = Object.prototype.toString.call(value);
    if (tag === "[object ArrayBuffer]" || tag === "[object SharedArrayBuffer]") {
      return Array.from(new Uint8Array(value));
    }

    return null;
  }

  function safeBytes(value) {
    try {
      return bytesFrom(value);
    } catch (_error) {
      return null;
    }
  }

  function errorDetails(error) {
    try {
      return {
        name: typeof error?.name === "string" ? error.name : "Error",
        message:
          typeof error?.message === "string" ? error.message : String(error),
      };
    } catch (_ignored) {
      return { name: "Error", message: "Unable to serialize error" };
    }
  }

  function append(device, fields) {
    if (!selected(device)) return;
    const ids = deviceIds(device);
    const entry = {
      timestamp: new Date().toISOString(),
      direction: fields.direction,
      method: fields.method,
      vendorId: ids.vendorId,
      productId: ids.productId,
      reportId: fields.reportId ?? null,
      bytes: fields.bytes ?? null,
      success: fields.success,
    };
    if (fields.error !== undefined) entry.error = errorDetails(fields.error);

    if (entries.length < maxEntries) {
      entries.push(entry);
    } else {
      entries[firstEntry] = entry;
      firstEntry = (firstEntry + 1) % maxEntries;
      dropped += 1;
    }
  }

  function observeResult(result, onSuccess, onFailure) {
    if (result && typeof result.then === "function") {
      return result.then(
        (value) => {
          onSuccess(value);
          return value;
        },
        (error) => {
          onFailure(error);
          throw error;
        },
      );
    }
    onSuccess(result);
    return result;
  }

  function traceCall(device, invoke, fields, successFields) {
    let result;
    try {
      result = invoke();
    } catch (error) {
      append(device, { ...fields, success: false, error });
      throw error;
    }
    return observeResult(
      result,
      (value) => {
        const additions = successFields ? successFields(value) : undefined;
        append(device, { ...fields, ...additions, success: true });
      },
      (error) => append(device, { ...fields, success: false, error }),
    );
  }

  function addInputListener(device) {
    if (
      !active ||
      listeners.has(device) ||
      typeof device?.addEventListener !== "function"
    ) {
      return;
    }

    const listener = (event) => {
      append(device, {
        direction: "in",
        method: "inputreport",
        reportId: event.reportId,
        bytes: safeBytes(event.data),
        success: true,
      });
    };
    device.addEventListener("inputreport", listener);
    listeners.set(device, listener);
  }

  function wrapMethod(prototype, name, makeWrapper) {
    const descriptor = Object.getOwnPropertyDescriptor(prototype, name);
    if (!descriptor || typeof descriptor.value !== "function") return;

    const original = descriptor.value;
    const wrapper = makeWrapper(original);
    Object.defineProperty(prototype, name, { ...descriptor, value: wrapper });
    restorers.push(() => {
      if (prototype[name] === wrapper) {
        Object.defineProperty(prototype, name, descriptor);
      }
    });
  }

  const prototype = root.HIDDevice?.prototype;
  if (!prototype) {
    throw new Error("HIDDevice is unavailable in this JavaScript realm");
  }

  wrapMethod(prototype, "open", (original) =>
    function tracedOpen(...args) {
      return traceCall(
        this,
        () => Reflect.apply(original, this, args),
        { direction: "control", method: "open" },
        () => {
          addInputListener(this);
        },
      );
    },
  );

  for (const name of ["sendReport", "sendFeatureReport"]) {
    wrapMethod(prototype, name, (original) =>
      function tracedSend(reportId, data, ...remaining) {
        const bytes = safeBytes(data);
        return traceCall(
          this,
          () => Reflect.apply(original, this, [reportId, data, ...remaining]),
          {
            direction: "out",
            method: name,
            reportId,
            bytes,
          },
        );
      },
    );
  }

  wrapMethod(prototype, "receiveFeatureReport", (original) =>
    function tracedReceive(reportId, ...remaining) {
      return traceCall(
        this,
        () => Reflect.apply(original, this, [reportId, ...remaining]),
        {
          direction: "in",
          method: "receiveFeatureReport",
          reportId,
        },
        (data) => ({ bytes: safeBytes(data) }),
      );
    },
  );

  // getDevices() only enumerates devices already granted to this origin. It
  // neither opens a permission prompt nor sends traffic to a device.
  const getDevices = root.navigator?.hid?.getDevices;
  if (typeof getDevices === "function") {
    try {
      Promise.resolve(Reflect.apply(getDevices, root.navigator.hid, []))
        .then((devices) => {
          if (active) devices.forEach(addInputListener);
        })
        .catch(() => {
          // Capture remains useful through open() if enumeration is rejected.
        });
    } catch (_error) {
      // Capture remains useful through open() if enumeration throws.
    }
  }

  function snapshot() {
    const orderedEntries = Array.from(
      { length: entries.length },
      (_, index) => entries[(firstEntry + index) % entries.length],
    );
    return {
      format: "webhid-trace-v1",
      target: target && { ...target },
      maxEntries,
      dropped,
      active,
      entries: orderedEntries.map((entry) => ({
        ...entry,
        bytes: entry.bytes && entry.bytes.slice(),
        error: entry.error && { ...entry.error },
      })),
    };
  }

  const api = {
    __webhidTrace: true,

    select(selection) {
      if (!selection || typeof selection !== "object") {
        throw new TypeError("select() requires {vendorId, productId}");
      }
      target = {
        vendorId: requireUsbId(selection.vendorId, "vendorId"),
        productId: requireUsbId(selection.productId, "productId"),
      };
      return { ...target };
    },

    clearSelection() {
      target = null;
    },

    clear() {
      entries.length = 0;
      firstEntry = 0;
      dropped = 0;
    },

    snapshot,

    download(filename) {
      const safeName =
        typeof filename === "string" && filename.length > 0
          ? filename
          : `webhid-trace-${new Date().toISOString().replace(/[:.]/g, "-")}.json`;
      const blob = new root.Blob([JSON.stringify(snapshot(), null, 2)], {
        type: "application/json",
      });
      const url = root.URL.createObjectURL(blob);
      const anchor = root.document.createElement("a");
      anchor.href = url;
      anchor.download = safeName;
      anchor.style.display = "none";
      root.document.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
      root.setTimeout(() => root.URL.revokeObjectURL(url), 0);
      return safeName;
    },

    stop() {
      if (!active) return snapshot();
      active = false;
      while (restorers.length > 0) restorers.pop()();
      for (const [device, listener] of listeners) {
        device.removeEventListener("inputreport", listener);
      }
      listeners.clear();
      return snapshot();
    },
  };

  return api;
});
