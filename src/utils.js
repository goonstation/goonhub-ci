import fs from 'fs'

const debug = true

export const serversFolder = '/ss13_servers'
export const serverConfig = JSON.parse(fs.readFileSync('/ss13_servers.conf'))

export function log(msg) {
	if (!debug) return
	const now = (new Date()).toISOString().slice(0, 19).replace(/-/g, "/").replace("T", " ")
	const out = `[${now}] ${msg}`
	console.log(out)
	fs.appendFile('../logs/build.log', `${out}\n`, err => {})
}

export function shuffleArray(array) {
	for (let i = array.length - 1; i > 0; i--) {
		const j = Math.floor(Math.random() * (i + 1));
		[array[i], array[j]] = [array[j], array[i]];
	}
}
