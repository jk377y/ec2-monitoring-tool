'use strict';
// how often to check the JSON file
const REFRESH_MS = 2000;
// anything older than 12 seconds is probably stale
const MAX_AGE_SECONDS = 12;
// warning levels for CPU, memory, and disk
const WARN_PERCENT = 70;
const HIGH_PERCENT = 90;
// just makes finding HTML elements easier
const el = (id) => document.getElementById(id);
let hasReceivedData = false;
let wasConnected = false;
let lastStates = {};
let recentEvents = [];
let isLoading = false;
// add a message to the recent events section
function addEvent(message, type = 'ok') {
	const time = new Date().toLocaleTimeString();
	recentEvents.unshift({ message: `[${time}] ${message}`, type });
	// only keep the newest 7 events
	recentEvents = recentEvents.slice(0, 7);
	const list = el('event-list');
	list.replaceChildren();
	for (const event of recentEvents) {
		const item = document.createElement('li');
		item.className = `event ${event.type}`;
		item.textContent = event.message;
		list.appendChild(item);
	}
}
// change the connection indicator at the top
function setConnection(status) {
	const node = el('connection');
	const labels = {
		pending: 'Connecting...',
		connected: 'Connected',
		disconnected: 'Disconnected / Stale',
	};
	node.className = `connection ${status}`;
	const dot = document.createElement('span');
	dot.className = 'status-dot';
	node.replaceChildren(dot, document.createTextNode(labels[status]));
}
// update one of the CPU, memory, or disk cards
function updateMetric(name, rawValue) {
	const value = Number(rawValue);
	if (!Number.isFinite(value)) {
		throw new Error(`Invalid ${name} reading`);
	}
	// decide which color/status the card should use
	let state = 'healthy';
	if (value >= HIGH_PERCENT) {
		state = 'high';
	} else if (value >= WARN_PERCENT) {
		state = 'warning';
	}
	const card = el(`${name}-card`);
	card.classList.remove('pending', 'healthy', 'warning', 'high');
	card.classList.add(state);
	// update the number and progress bar
	el(`${name}-value`).textContent = `${value.toFixed(1)}%`;
	el(`${name}-bar`).style.width = `${Math.min(100, Math.max(0, value))}%`;
	el(`${name}-status`).textContent = state === 'high' ? 'High' : state === 'warning' ? 'Warning' : 'Healthy';
	// add an event when a metric changes its status
	if (lastStates[name] && lastStates[name] !== state) {
		if (state === 'healthy') {
			addEvent(`${name.toUpperCase()} returned to normal`);
		} else {
			addEvent(`${name.toUpperCase()} entered ${state} range`, 'warn');
		}
	}
	lastStates[name] = state;
}
// format the network traffic into readable units
function formatNetwork(kib) {
	const value = Number(kib);
	if (!Number.isFinite(value)) return '--';
	if (value >= 1024) {
		return `${(value / 1024).toFixed(1)} MiB/s`;
	}
	return `${value.toFixed(1)} KiB/s`;
}
// turn the metric indicators gray when readings aren't current
function setMetricsPending() {
	for (const name of ['cpu', 'memory', 'disk']) {
		const card = el(`${name}-card`);
		card.classList.remove('healthy', 'warning', 'high');
		card.classList.add('pending');
	}
}
// get the newest JSON file and update the dashboard
async function updateDashboard() {
	// don't start another request if one is still running
	if (isLoading) return;
	isLoading = true;
	try {
		// ask the server for the latest readings
		const response = await fetch(`data/metrics.json?t=${Date.now()}`, { cache: 'no-store' });
		if (!response.ok) {
			throw new Error(`HTTP ${response.status}`);
		}
		const data = await response.json();
		// make sure the timestamp is valid and recent
		const sampleTime = new Date(data.timestamp).getTime();
		if (!Number.isFinite(sampleTime)) {
			throw new Error('Invalid timestamp');
		}
		const age = (Date.now() - sampleTime) / 1000;
		if (age > MAX_AGE_SECONDS || age < -60) {
			throw new Error('Monitoring data is stale');
		}
		// fill the instance information
		el('instance-host').textContent = data.hostname || 'Unknown';
		el('instance-os').textContent = 'Linux EC2';
		el('last-update').textContent = age < 2 ? 'Just now' : `${Math.floor(age)} seconds ago`;
		// update the three percentage cards
		updateMetric('cpu', data.cpu_percent);
		updateMetric('memory', data.memory_percent);
		updateMetric('disk', data.disk_percent);
		// update network download and upload
		el('network-rx').textContent = formatNetwork(data.network_rx_kib_s);
		el('network-tx').textContent = formatNetwork(data.network_tx_kib_s);
		// record the first connection or a recovery
		if (!hasReceivedData) {
			addEvent('First system readings received');
		} else if (!wasConnected) {
			addEvent('Monitoring connection restored');
		}
		hasReceivedData = true;
		wasConnected = true;
		setConnection('connected');
	} catch (error) {
		// avoid reporting an error every two seconds
		if (hasReceivedData && wasConnected) {
			addEvent(`Monitoring unavailable: ${error.message}`, 'error');
		}
		wasConnected = false;
		setConnection(hasReceivedData ? 'disconnected' : 'pending');
		setMetricsPending();
		el('last-update').textContent = hasReceivedData ? 'No current readings' : 'Waiting for first reading...';
	} finally {
		isLoading = false;
	}
}
// start with gray indicators until it gets real data
setMetricsPending();
setConnection('pending');
// check immediately, then continue every 2 seconds
updateDashboard();
setInterval(updateDashboard, REFRESH_MS);
