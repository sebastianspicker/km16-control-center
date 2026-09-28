"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  installWebHIDTrace,
} = require("../../tools/browser/webhid-trace.js");

function makeEnvironment(devices = []) {
  class MockHIDDevice extends EventTarget {
    constructor(vendorId, productId) {
      super();
      this.vendorId = vendorId;
      this.productId = productId;
      this.calls = [];
    }

    open() {
      this.calls.push(["open"]);
      return Promise.resolve("opened");
    }

    sendReport(reportId, data) {
      this.calls.push(["sendReport", reportId, data]);
      return Promise.resolve("sent");
    }

    sendFeatureReport(reportId, data) {
      this.calls.push(["sendFeatureReport", reportId, data]);
      return Promise.resolve("feature-sent");
    }

    receiveFeatureReport(reportId) {
      this.calls.push(["receiveFeatureReport", reportId]);
      const backing = Uint8Array.from([0xee, 0x10, 0x20, 0xdd]);
      return Promise.resolve(new DataView(backing.buffer, 1, 2));
    }
  }

  return {
    HIDDevice: MockHIDDevice,
    navigator: { hid: { getDevices: async () => devices } },
  };
}

function inputReport(reportId, data) {
  const event = new Event("inputreport");
  Object.defineProperties(event, {
    reportId: { value: reportId },
    data: { value: data },
  });
  return event;
}

test("captures exact view bytes and preserves method arguments and results", async () => {
  const env = makeEnvironment();
  const trace = installWebHIDTrace(env);
  const device = new env.HIDDevice(0x28e9, 0x3145);
  trace.select({ vendorId: 0x28e9, productId: 0x3145 });

  const backing = Uint8Array.from([0xaa, 1, 2, 3, 0xbb]);
  const view = new Uint8Array(backing.buffer, 1, 3);
  assert.equal(await device.sendReport(7, view), "sent");
  assert.deepEqual(device.calls[0], ["sendReport", 7, view]);
  const received = await device.receiveFeatureReport(9);
  assert.ok(received instanceof DataView);
  assert.deepEqual(device.calls[1], ["receiveFeatureReport", 9]);

  const entries = trace.snapshot().entries;
  assert.deepEqual(entries[0].bytes, [1, 2, 3]);
  assert.deepEqual(entries[1].bytes, [0x10, 0x20]);
  assert.deepEqual(
    entries.map(({ direction, reportId, success }) => ({
      direction,
      reportId,
      success,
    })),
    [
      { direction: "out", reportId: 7, success: true },
      { direction: "in", reportId: 9, success: true },
    ],
  );
  trace.stop();
});

test("forwards rejection identity and records failed outgoing bytes", async () => {
  const env = makeEnvironment();
  const failure = new DOMException("device vanished", "NetworkError");
  env.HIDDevice.prototype.sendFeatureReport = function sendFeatureReport(
    reportId,
    data,
  ) {
    this.calls.push(["sendFeatureReport", reportId, data]);
    return Promise.reject(failure);
  };
  const trace = installWebHIDTrace(env);
  const device = new env.HIDDevice(0x28e9, 0x3145);
  trace.select({ vendorId: 0x28e9, productId: 0x3145 });
  const backing = Uint8Array.from([8, 9, 10, 11]);
  const view = new DataView(backing.buffer, 1, 2);

  await assert.rejects(device.sendFeatureReport(4, view), (error) => error === failure);
  assert.deepEqual(device.calls[0], ["sendFeatureReport", 4, view]);
  const [entry] = trace.snapshot().entries;
  assert.deepEqual(entry.bytes, [9, 10]);
  assert.equal(entry.success, false);
  assert.deepEqual(entry.error, {
    name: "NetworkError",
    message: "device vanished",
  });
  trace.stop();
});

test("preserves synchronous returns and thrown error identity", () => {
  const env = makeEnvironment();
  const failure = new TypeError("invalid report");
  env.HIDDevice.prototype.sendReport = function sendReport(reportId, data) {
    this.calls.push(["sendReport", reportId, data]);
    return "sync-sent";
  };
  env.HIDDevice.prototype.receiveFeatureReport = function receiveFeatureReport() {
    throw failure;
  };
  const trace = installWebHIDTrace(env);
  const device = new env.HIDDevice(0x28e9, 0x3145);
  trace.select({ vendorId: 0x28e9, productId: 0x3145 });

  assert.equal(device.sendReport(3, Uint8Array.of(4)), "sync-sent");
  assert.throws(() => device.receiveFeatureReport(7), (error) => error === failure);
  assert.deepEqual(
    trace.snapshot().entries.map(({ method, success }) => ({ method, success })),
    [
      { method: "sendReport", success: true },
      { method: "receiveFeatureReport", success: false },
    ],
  );
  trace.stop();
});

test("requires selection and filters by both vendor and product ID", async () => {
  const env = makeEnvironment();
  const target = new env.HIDDevice(0x28e9, 0x3145);
  const wrongProduct = new env.HIDDevice(0x28e9, 0x9999);
  const trace = installWebHIDTrace(env);

  await target.sendReport(1, Uint8Array.of(1));
  assert.equal(trace.snapshot().entries.length, 0);

  trace.select({ vendorId: 0x28e9, productId: 0x3145 });
  await wrongProduct.sendReport(2, Uint8Array.of(2));
  await target.sendReport(3, Uint8Array.of(3));
  assert.deepEqual(
    trace.snapshot().entries.map((entry) => entry.reportId),
    [3],
  );
  trace.stop();
});

test("listens to already authorized devices and devices after open", async () => {
  const env = makeEnvironment();
  const authorized = new env.HIDDevice(0x28e9, 0x3145);
  env.navigator.hid.getDevices = async () => [authorized];
  const trace = installWebHIDTrace(env);
  trace.select({ vendorId: 0x28e9, productId: 0x3145 });
  await Promise.resolve();
  await Promise.resolve();

  const incomingBacking = Uint8Array.from([0xff, 5, 6, 0xee]);
  authorized.dispatchEvent(
    inputReport(12, new DataView(incomingBacking.buffer, 1, 2)),
  );

  const newlyOpened = new env.HIDDevice(0x28e9, 0x3145);
  assert.equal(await newlyOpened.open(), "opened");
  newlyOpened.dispatchEvent(inputReport(13, Uint8Array.of(7, 8)));

  const entries = trace.snapshot().entries;
  assert.deepEqual(
    entries.filter((entry) => entry.method === "inputreport").map((entry) => entry.bytes),
    [
      [5, 6],
      [7, 8],
    ],
  );
  assert.equal(entries.find((entry) => entry.method === "open").success, true);
  trace.stop();
});

test("stop restores methods, removes input listeners, and is idempotent", async () => {
  const env = makeEnvironment();
  const originalSend = env.HIDDevice.prototype.sendReport;
  const device = new env.HIDDevice(0x28e9, 0x3145);
  env.navigator.hid.getDevices = async () => [device];
  const trace = installWebHIDTrace(env);
  trace.select({ vendorId: 0x28e9, productId: 0x3145 });
  await Promise.resolve();
  await Promise.resolve();

  trace.stop();
  trace.stop();
  assert.equal(env.HIDDevice.prototype.sendReport, originalSend);
  await device.sendReport(1, Uint8Array.of(1));
  device.dispatchEvent(inputReport(2, Uint8Array.of(2)));
  assert.equal(trace.snapshot().entries.length, 0);
});

test("bounds retained entries and reports overflow", async () => {
  const env = makeEnvironment();
  const trace = installWebHIDTrace(env, { maxEntries: 2 });
  const device = new env.HIDDevice(0x28e9, 0x3145);
  trace.select({ vendorId: 0x28e9, productId: 0x3145 });

  await device.sendReport(1, Uint8Array.of(1));
  await device.sendReport(2, Uint8Array.of(2));
  await device.sendReport(3, Uint8Array.of(3));

  const capture = trace.snapshot();
  assert.equal(capture.maxEntries, 2);
  assert.equal(capture.dropped, 1);
  assert.deepEqual(
    capture.entries.map((entry) => entry.reportId),
    [2, 3],
  );
  trace.stop();
});

test("retains chronological order through repeated wraparound and clear", async () => {
  const env = makeEnvironment();
  const trace = installWebHIDTrace(env, { maxEntries: 3 });
  const device = new env.HIDDevice(0x28e9, 0x3145);
  trace.select({ vendorId: 0x28e9, productId: 0x3145 });

  for (let reportId = 1; reportId <= 8; reportId += 1) {
    await device.sendReport(reportId, Uint8Array.of(reportId));
  }
  assert.deepEqual(
    trace.snapshot().entries.map((entry) => entry.reportId),
    [6, 7, 8],
  );
  assert.equal(trace.snapshot().dropped, 5);

  trace.clear();
  await device.sendReport(9, Uint8Array.of(9));
  const capture = trace.snapshot();
  assert.equal(capture.dropped, 0);
  assert.deepEqual(capture.entries.map((entry) => entry.reportId), [9]);
  trace.stop();
});
