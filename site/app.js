'use strict';

const $ = (id) => document.getElementById(id);

// Each kind is printed in one of four inks. The ink names the consequence, not
// the mechanism: what reaches the front app, the Mac, another app, or a process.
const kinds = {
  shortcut: {name: 'Shortcut', tag: 'Keys', ink: 'types', payload: 'Keyboard shortcut'},
  snippet: {name: 'Text snippet', tag: 'Text', ink: 'types', payload: 'Text to insert'},
  system: {name: 'System action', tag: 'System', ink: 'adjusts', payload: 'System action identifier'},
  launchApp: {name: 'Launch app', tag: 'App', ink: 'opens', payload: 'Bundle identifier'},
  profileSwitch: {name: 'Switch profile', tag: 'Switch', ink: 'opens', payload: 'Destination preset ID'},
  shell: {name: 'Shell process', tag: 'Shell', ink: 'runs', payload: 'Process payload (JSON)'},
  agentAction: {name: 'Agent action', tag: 'Agent', ink: 'runs', payload: 'Agent action identifier'},
  obsAction: {name: 'OBS action', tag: 'OBS', ink: 'runs', payload: 'OBS action identifier'},
  disabled: {name: 'Disabled', tag: 'Off', ink: 'types', payload: 'Payload'},
};
const inkNames = {
  types: 'Types into the front app',
  adjusts: 'Adjusts the Mac',
  opens: 'Opens or switches',
  runs: 'Runs outside the app',
};
const groups = [
  ['Everyday', ['desktop', 'window-management', 'personal-automations']],
  ['Development', ['agent-deck', 'developer', 'git-review', 'terminal']],
  ['Work & Writing', ['research-writing', 'meetings', 'presentations']],
  ['Media & Design', ['photo-editing', 'video-editing', '3d-modelling', 'music-production', 'recording-streaming', 'creative']],
];
const dialNames = ['Upper left', 'Upper right', 'Main dial'];
const turns = [['ccw', 'Counterclockwise', '◂'], ['press', 'Press', '●'], ['cw', 'Clockwise', '▸']];
const keyIDs = Array.from({length: 16}, (_, index) => `key-${Math.floor(index / 4)}-${index % 4}`);
const compact = matchMedia('(max-width: 719px)');
const isMac = /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);
let original;
let profiles = [];
let profile;
let selected = 'key-0-0';
let events = [];
let angles = [0, 0, 0];

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}
function kindOf(assigned) { return kinds[assigned.kind] || {name: assigned.kind, tag: assigned.kind, ink: 'types', payload: 'Payload'}; }
function bindingFor(id) { return profile.bindings.find((binding) => binding.controlID === id).action; }
function action() { return bindingFor(selected); }
function controlName(id) {
  const [type, row, column] = id.split('-');
  return type === 'key' ? `Key ${Number(row) * 4 + Number(column) + 1}` : `${dialNames[Number(row)]} · ${{ccw: 'Counterclockwise', cw: 'Clockwise', press: 'Press'}[column]}`;
}
function controlPosition(id) {
  const [type, row, column] = id.split('-');
  return type === 'key' ? `Row ${Number(row) + 1} · Column ${Number(column) + 1}` : `Knob ${Number(row) + 1} of 3`;
}
function shortcutDisplay(value) {
  const symbols = {cmd: '⌘', shift: '⇧', alt: '⌥', ctrl: '⌃', enter: '↩', esc: '⎋', escape: '⎋', tab: '⇥', delete: '⌫', space: 'Space', up: '↑', down: '↓', left: '←', right: '→', pageup: '⇞', pagedown: '⇟', plus: '+', minus: '−', backtick: '`'};
  return value.split('+').map((part) => symbols[part] || part.toUpperCase()).join('');
}
// The short code printed under each legend: what the control literally sends.
function codeFor(assigned) {
  const value = assigned.parameter.trim();
  switch (assigned.kind) {
    case 'shortcut': return shortcutDisplay(value);
    case 'launchApp': return value.split('.').pop() || value;
    case 'profileSwitch': return `→ ${value}`;
    case 'disabled': return '—';
    case 'snippet': return `“${value}”`;
    case 'shell':
      try {
        const payload = JSON.parse(value);
        return String(payload.executable || '').split('/').pop() || 'process';
      } catch { return 'process'; }
    default: return value;
  }
}

function renderProfiles() {
  const query = $('search').value.trim().toLowerCase();
  const matches = profiles.filter((item) => `${item.name} ${item.summary}`.toLowerCase().includes(query));
  $('profiles').replaceChildren();
  $('profile-count').textContent = matches.length === profiles.length ? String(profiles.length) : `${matches.length} of ${profiles.length}`;
  for (const [name, ids] of groups) {
    const items = matches.filter((item) => ids.includes(item.presetID));
    if (!items.length) continue;
    const list = element('ul', 'index-group');
    list.setAttribute('aria-label', name);
    items.forEach((item) => {
      const button = element('button', 'index-item');
      button.append(element('span', 'index-number', String(profiles.indexOf(item) + 1).padStart(2, '0')), element('span', 'index-name', item.name));
      button.dataset.profile = item.id;
      button.setAttribute('aria-current', String(item.id === profile.id));
      button.addEventListener('click', () => {
        profile = item;
        selected = 'key-0-0';
        renderWorkspace();
        renderProfiles();
        if (compact.matches) {
          setSheet(false);
          $('card').scrollIntoView({block: 'start'});
        } else {
          [...$('profiles').querySelectorAll('button')].find((candidate) => candidate.dataset.profile === item.id)?.focus();
        }
      });
      const row = element('li');
      row.append(button);
      list.append(row);
    });
    $('profiles').append(element('p', 'index-group-label', name), list);
  }
  if (!matches.length) $('profiles').append(element('p', 'index-empty', `No preset matches “${$('search').value.trim()}”.`));
}
function controlButton(id, className) {
  const assigned = bindingFor(id);
  const button = element('button', `${className} ink-${kindOf(assigned).ink}`);
  button.dataset.control = id;
  button.setAttribute('aria-label', `${controlName(id)}: ${assigned.label || 'Untitled'}, ${kindOf(assigned).name}`);
  button.addEventListener('click', () => selectControl(id));
  return button;
}
function renderControls() {
  $('keys').replaceChildren();
  keyIDs.forEach((id, index) => {
    const assigned = bindingFor(id);
    const button = controlButton(id, 'key');
    const top = element('span', 'key-top');
    top.append(element('span', 'key-number', String(index + 1).padStart(2, '0')));
    // Shortcuts are the default legend; only the other kinds carry a printed tag.
    if (assigned.kind !== 'shortcut') top.append(element('span', 'key-tag', kindOf(assigned).tag));
    button.append(top, element('span', 'key-name', assigned.label || 'Untitled'), element('span', 'key-code', codeFor(assigned)));
    $('keys').append(button);
  });
  $('dials').replaceChildren();
  dialNames.forEach((name, index) => {
    const knob = element('div', index === 2 ? 'knob knob-main' : 'knob');
    const dial = controlButton(`encoder-${index}-press`, 'dial');
    const pointer = element('span', 'dial-pointer');
    pointer.style.setProperty('--angle', `${angles[index]}deg`);
    dial.append(pointer);
    const legends = element('div', 'knob-legends');
    legends.append(element('p', 'knob-name', name));
    for (const [input, , glyph] of turns) {
      const id = `encoder-${index}-${input}`;
      const assigned = bindingFor(id);
      const legend = controlButton(id, 'legend');
      legend.append(element('span', 'legend-glyph', glyph), element('span', 'legend-name', assigned.label || 'Untitled'), element('span', 'legend-code', codeFor(assigned)));
      legends.append(legend);
    }
    knob.append(dial, legends);
    $('dials').append(knob);
  });
  updateSelection();
}
function updateSelection() {
  document.querySelectorAll('[data-control]').forEach((button) => button.setAttribute('aria-pressed', String(button.dataset.control === selected)));
}
function selectControl(id) {
  selected = id;
  updateSelection();
  renderInspector();
}
function renderInspector() {
  const assigned = action();
  const kind = kindOf(assigned);
  $('entry').className = `entry ink-${kind.ink}`;
  $('control-position').textContent = controlPosition(selected);
  $('control-name').textContent = controlName(selected);
  $('action-name').value = assigned.label;
  $('kind-name').textContent = `${kind.name} · ${inkNames[kind.ink]}`;
  $('action-detail').textContent = assigned.detail || 'No description for this assignment.';
  $('payload-label').textContent = kind.payload;
  $('payload').value = assigned.parameter;
  $('payload').rows = assigned.kind === 'shell' || assigned.kind === 'snippet' ? 4 : 1;
  $('shortcut-preview').textContent = codeFor(assigned);
  $('target-section').hidden = !['shortcut', 'system', 'snippet', 'launchApp'].includes(assigned.kind);
  $('target').textContent = assigned.targetBundleID || (assigned.kind === 'launchApp' ? assigned.parameter : 'The app you used last');
  $('edit-status').textContent = '';
}
function renderWorkspace() {
  const group = groups.find(([, ids]) => ids.includes(profile.presetID));
  $('profile-number').textContent = `Preset ${String(profiles.indexOf(profile) + 1).padStart(2, '0')} of ${profiles.length}`;
  $('profile-group').textContent = group ? group[0] : '';
  $('profile-name').textContent = profile.name;
  $('preset-bar-name').textContent = profile.name;
  $('profile-summary').textContent = profile.summary;
  renderControls();
  renderInspector();
}
function time(date) {
  return date.toLocaleTimeString([], {hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false});
}
function renderLog() {
  if (!events.length) {
    $('activity').replaceChildren(element('li', 'log-empty', 'No previews yet. Each preview is recorded here and nothing else happens.'));
    return;
  }
  $('activity').replaceChildren(...events.map((event, index) => {
    const line = element('li', `log-line ink-${event.ink}${index === 0 ? ' log-new' : ''}`);
    line.append(
      element('time', 'log-time', time(event.date)),
      element('span', 'log-where', `${event.profile} · ${event.control}`),
      element('strong', 'log-label', event.label || 'Untitled'),
      element('code', 'log-code', event.code),
      element('span', 'log-result', 'not run'),
    );
    return line;
  }));
}
function animate(id) {
  const [type, index, input] = id.split('-');
  if (type === 'encoder' && input !== 'press') {
    angles[Number(index)] += input === 'cw' ? 30 : -30;
    document.querySelector(`[data-control="encoder-${index}-press"] .dial-pointer`)?.style.setProperty('--angle', `${angles[Number(index)]}deg`);
    return;
  }
  const target = document.querySelector(`[data-control="${id}"]`);
  target?.classList.remove('is-firing');
  void target?.offsetWidth;
  target?.classList.add('is-firing');
}
function preview() {
  const assigned = action();
  events.unshift({date: new Date(), profile: profile.name, control: controlName(selected), label: assigned.label, code: codeFor(assigned), ink: kindOf(assigned).ink});
  events = events.slice(0, 6);
  renderLog();
  animate(selected);
  $('edit-status').textContent = `Previewed ${assigned.label || 'this assignment'}. Nothing was run.`;
}
function reset() {
  profiles = structuredClone(original.profiles);
  profile = profiles.find((item) => item.id === original.activeProfileID) || profiles[0];
  selected = 'key-0-0';
  events = [];
  angles = [0, 0, 0];
  $('search').value = '';
  renderLog();
  renderProfiles();
  renderWorkspace();
}
function validate(data) {
  if (!Array.isArray(data.profiles) || !data.profiles.length) throw new Error('No profiles');
  for (const item of data.profiles) {
    if (typeof item.name !== 'string' || !Array.isArray(item.bindings)) throw new Error('Invalid profile');
    const required = keyIDs.concat([0, 1, 2].flatMap((index) => ['ccw', 'cw', 'press'].map((direction) => `encoder-${index}-${direction}`)));
    for (const id of required) {
      const assigned = item.bindings.find((binding) => binding.controlID === id)?.action;
      if (!assigned || !['label', 'kind', 'parameter'].every((key) => typeof assigned[key] === 'string')) throw new Error('Incomplete assignments');
    }
  }
  return data;
}
async function load() {
  $('load-state').replaceChildren(element('p', '', 'Loading factory presets…'));
  $('load-state').classList.remove('is-error');
  try {
    const response = await fetch('./presets.json');
    if (!response.ok) throw new Error('Preset request failed');
    original = validate(await response.json());
    reset();
    $('load-state').hidden = true;
    $('app').hidden = false;
    $('reset').disabled = false;
  } catch {
    $('load-state').classList.add('is-error');
    $('load-state').replaceChildren(
      element('p', 'load-title', 'The factory presets did not load.'),
      element('p', '', 'The page needs presets.json from the same folder. If you opened index.html from disk, serve the folder over HTTP instead.'),
    );
    const retry = element('button', 'text-button', 'Try again');
    retry.addEventListener('click', load);
    $('load-state').append(retry);
  }
}
function setSheet(open, restoreFocus = true) {
  $('sidebar').classList.toggle('open', open);
  $('library-toggle').setAttribute('aria-expanded', String(open));
  document.body.classList.toggle('sheet-open', open);
  if (open) $('search').focus();
  else if (restoreFocus) $('library-toggle').focus();
}

$('preview-shortcut').textContent = isMac ? '⌘↩' : 'Ctrl ↩';
$('preview-shortcut').setAttribute('aria-label', isMac ? 'Command Return' : 'Control Enter');
$('search').addEventListener('input', renderProfiles);
$('library-toggle').addEventListener('click', () => setSheet(!$('sidebar').classList.contains('open')));
$('reset').addEventListener('click', () => { reset(); $('edit-status').textContent = 'Factory presets restored.'; });
$('preview').addEventListener('click', preview);
$('action-name').addEventListener('input', () => {
  action().label = $('action-name').value;
  renderControls();
  $('edit-status').textContent = 'Name changed in this tab.';
});
$('payload').addEventListener('input', () => {
  action().parameter = $('payload').value;
  $('shortcut-preview').textContent = codeFor(action());
  if (action().kind === 'launchApp') $('target').textContent = action().parameter;
  renderControls();
  $('edit-status').textContent = 'Payload changed in this tab. It will not run.';
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Enter' && (isMac ? event.metaKey : event.ctrlKey) && !$('app').hidden) {
    event.preventDefault();
    preview();
  } else if (event.key === 'Escape' && $('sidebar').classList.contains('open')) {
    setSheet(false);
  }
});
$('sheet-close').addEventListener('click', () => setSheet(false));
compact.addEventListener('change', () => { if (!compact.matches && $('sidebar').classList.contains('open')) setSheet(false, false); });
load();
