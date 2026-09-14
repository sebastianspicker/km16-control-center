'use strict';

const $ = (id) => document.getElementById(id);
const kinds = {
  shortcut: ['Shortcut', '⌘', 'Keyboard shortcut'],
  launchApp: ['Launch app', '▢', 'Bundle identifier'],
  system: ['System', '◈', 'System action'],
  profileSwitch: ['Switch profile', '▦', 'Destination preset ID'],
  shell: ['Shell', '⌁', 'Process payload (JSON)'],
  agentAction: ['Agent action', '✧', 'Agent action identifier'],
  snippet: ['Text snippet', '≡', 'Text to insert'],
  obsAction: ['OBS action', '◉', 'OBS action identifier'],
};
const groups = [
  ['Everyday', ['desktop', 'window-management', 'personal-automations']],
  ['Development', ['agent-deck', 'developer', 'git-review', 'terminal']],
  ['Work & Writing', ['research-writing', 'meetings', 'presentations']],
  ['Media & Design', ['photo-editing', 'video-editing', '3d-modelling', 'music-production', 'recording-streaming', 'creative']],
];
const profileIcons = ['▤', '⊞', 'ϟ', '✧', '{}', '⑂', '⌁', '▱', '◫', '▢', '◩', '▷', '◇', '♫', '◉', '✎'];
const dialNames = ['Upper left', 'Upper right', 'Main dial'];
let original;
let profiles = [];
let profile;
let selected = 'key-0-0';
let events = [];

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}
function action() { return profile.bindings.find((binding) => binding.controlID === selected).action; }
function controlName(id) {
  const [type, row, column] = id.split('-');
  return type === 'key' ? `Key ${Number(row) * 4 + Number(column) + 1}` : `${dialNames[Number(row)]} · ${{ccw: 'Counterclockwise', cw: 'Clockwise', press: 'Press'}[column]}`;
}
function selectControl(id) {
  selected = id;
  updateSelection();
  renderInspector();
}
function updateSelection() {
  document.querySelectorAll('[data-control]').forEach((button) => button.setAttribute('aria-pressed', String(button.dataset.control === selected)));
}
function renderProfiles() {
  const query = $('search').value.trim().toLowerCase();
  const matches = profiles.filter((item) => `${item.name} ${item.summary}`.toLowerCase().includes(query));
  $('profiles').replaceChildren();
  $('profile-count').textContent = `${matches.length} / ${profiles.length}`;
  for (const [name, ids] of groups) {
    const items = matches.filter((item) => ids.includes(item.presetID));
    if (!items.length) continue;
    $('profiles').append(element('p', 'group-label', name));
    items.forEach((item) => {
      const button = element('button', 'profile-button');
      button.append(element('span', 'symbol', profileIcons[profiles.indexOf(item)] || '▦'), element('span', '', item.name));
      button.dataset.profile = item.id;
      button.setAttribute('aria-current', String(item.id === profile.id));
      button.addEventListener('click', () => {
        profile = item;
        selected = 'key-0-0';
        renderWorkspace();
        renderProfiles();
        if (matchMedia('(max-width: 640px)').matches) {
          $('sidebar').classList.remove('open');
          $('library-toggle').setAttribute('aria-expanded', 'false');
          $('library-toggle').focus();
        } else {
          [...$('profiles').querySelectorAll('button')].find((candidate) => candidate.dataset.profile === item.id)?.focus();
        }
      });
      $('profiles').append(button);
    });
  }
  if (!matches.length) $('profiles').append(element('p', 'no-results', 'No presets match your search.'));
}
function bindingButton(id, className) {
  const binding = profile.bindings.find((item) => item.controlID === id);
  const button = element('button', className);
  button.dataset.control = id;
  button.setAttribute('aria-label', `${controlName(id)}: ${binding.action.label}`);
  button.title = `${controlName(id)}: ${binding.action.label}`;
  button.addEventListener('click', () => selectControl(id));
  return button;
}
function renderControls() {
  $('keys').replaceChildren();
  for (let index = 0; index < 16; index += 1) {
    const id = `key-${Math.floor(index / 4)}-${index % 4}`;
    const assigned = profile.bindings.find((item) => item.controlID === id).action;
    const button = bindingButton(id, 'key');
    const top = element('span', 'key-top');
    top.append(element('span', 'key-symbol', kinds[assigned.kind]?.[1] || '◇'), element('span', 'key-number', String(index + 1).padStart(2, '0')));
    button.append(top, element('span', 'key-label', assigned.label));
    $('keys').append(button);
  }
  $('dials').replaceChildren();
  dialNames.forEach((name, index) => {
    const group = element('div', 'dial-group');
    group.append(bindingButton(`encoder-${index}-press`, 'dial'), element('p', 'dial-label', name));
    const directions = element('div', 'dial-directions');
    for (const [direction, glyph] of [['ccw', '↶'], ['cw', '↷']]) {
      const button = bindingButton(`encoder-${index}-${direction}`, 'turn');
      button.textContent = glyph;
      directions.append(button);
    }
    group.append(directions);
    if (index === 2) group.append(element('p', 'dial-help', 'TURN · PRESS'));
    $('dials').append(group);
  });
  updateSelection();
}
function shortcutDisplay(value) {
  const symbols = {cmd: '⌘', shift: '⇧', alt: '⌥', ctrl: '⌃', enter: '↩', space: 'Space', up: '↑', down: '↓', left: '←', right: '→', tab: '⇥', escape: '⎋'};
  return value.split('+').map((part) => symbols[part] || part.toUpperCase()).join('');
}
function renderInspector() {
  const assigned = action();
  const [name, icon, payload] = kinds[assigned.kind] || [assigned.kind, '◇', 'Payload'];
  $('control-name').textContent = controlName(selected);
  $('action-icon').textContent = icon;
  $('kind-name').textContent = name;
  $('action-name').value = assigned.label;
  $('action-detail').textContent = assigned.detail || 'No additional description.';
  $('action-type').textContent = name;
  $('payload-label').textContent = payload;
  $('payload').value = assigned.parameter;
  $('payload').rows = assigned.kind === 'shell' || assigned.kind === 'snippet' ? 5 : 2;
  $('shortcut-preview').hidden = assigned.kind !== 'shortcut';
  $('shortcut-preview').textContent = shortcutDisplay(assigned.parameter);
  $('target-section').hidden = !['shortcut', 'system', 'snippet', 'launchApp'].includes(assigned.kind);
  $('target').textContent = assigned.targetBundleID || (assigned.kind === 'launchApp' ? assigned.parameter : 'Last active app / system default');
  $('edit-status').textContent = '';
}
function renderWorkspace() {
  $('profile-name').textContent = profile.name;
  $('profile-summary').textContent = profile.summary;
  renderControls();
  renderInspector();
}
function preview() {
  const assigned = action();
  events.unshift({profile: profile.name, control: controlName(selected), label: assigned.label, kind: kinds[assigned.kind]?.[0] || assigned.kind, payload: assigned.parameter});
  events = events.slice(0, 3);
  $('activity').replaceChildren();
  events.forEach((event) => {
    const entry = element('p', 'activity-entry');
    entry.append(element('strong', '', `Previewed ${event.label || 'Untitled action'}`), element('small', '', `${event.profile} · ${event.control} · ${event.kind}`), element('span', 'activity-payload', ` — ${event.payload}`));
    $('activity').append(entry);
  });
  $('edit-status').textContent = 'Preview recorded. No action was executed.';
}
function reset() {
  profiles = structuredClone(original.profiles);
  profile = profiles.find((item) => item.id === original.activeProfileID) || profiles[0];
  selected = 'key-0-0';
  events = [];
  $('search').value = '';
  $('activity').replaceChildren(element('p', 'empty-activity', 'Your previews will appear here. Nothing is sent or executed.'));
  renderProfiles();
  renderWorkspace();
}
function validate(data) {
  if (!Array.isArray(data.profiles) || !data.profiles.length) throw new Error('No profiles');
  for (const item of data.profiles) {
    if (typeof item.name !== 'string' || !Array.isArray(item.bindings)) throw new Error('Invalid profile');
    const required = Array.from({length: 16}, (_, index) => `key-${Math.floor(index / 4)}-${index % 4}`).concat([0, 1, 2].flatMap((index) => ['ccw', 'cw', 'press'].map((direction) => `encoder-${index}-${direction}`)));
    for (const id of required) {
      const assigned = item.bindings.find((binding) => binding.controlID === id)?.action;
      if (!assigned || !['label', 'kind', 'parameter'].every((key) => typeof assigned[key] === 'string')) throw new Error('Incomplete assignments');
    }
  }
  return data;
}
async function load() {
  $('load-state').textContent = 'Loading factory presets…';
  try {
    const response = await fetch('./presets.json');
    if (!response.ok) throw new Error('Preset request failed');
    original = validate(await response.json());
    reset();
    $('load-state').hidden = true;
    $('app').hidden = false;
    $('reset').disabled = false;
  } catch {
    $('load-state').replaceChildren(element('p', '', 'Factory presets could not be loaded. Please try again.'));
    const retry = element('button', '', 'Retry loading');
    retry.addEventListener('click', load);
    $('load-state').append(retry);
  }
}
$('search').addEventListener('input', renderProfiles);
$('library-toggle').addEventListener('click', () => {
  const open = $('sidebar').classList.toggle('open');
  $('library-toggle').setAttribute('aria-expanded', String(open));
  if (open) $('search').focus();
});
$('reset').addEventListener('click', () => { reset(); $('edit-status').textContent = 'Factory presets restored.'; });
$('preview').addEventListener('click', preview);
$('action-name').addEventListener('input', () => {
  action().label = $('action-name').value;
  renderControls();
  $('edit-status').textContent = 'Assignment edited in this tab.';
});
$('payload').addEventListener('input', () => {
  action().parameter = $('payload').value;
  $('shortcut-preview').textContent = shortcutDisplay(action().parameter);
  if (action().kind === 'launchApp') $('target').textContent = action().parameter;
  $('edit-status').textContent = 'Payload edited in this tab. It will not be executed.';
});
load();
