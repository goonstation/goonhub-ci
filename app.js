import express from 'express'
import fs from 'fs'
import config from './config.js'
import Builder from './builder.js'

const hostname = '0.0.0.0'
const port = 3000

const app = express()
app.use(express.json())

const BuilderInstance = new Builder

app.use((req, res, next) => {
	if (req.header('Api-Key') === config.apiKey) next()
	else res.status(401).send('No.')
})

app.get('/status', (req, res) => {
	res.json({
		maxCompileJobs: BuilderInstance.maxCompileJobs,
		currentCompileJobs: BuilderInstance.currentCompileJobs,
		queuedJobs: BuilderInstance.queuedJobs.map(e => e.server)
	}).end()
})

app.post('/build', (req, res) => {
	const server = req.body.server
	if (!server) return res.status(400).json({error: "Missing server ID"})
	try {
		res.status(200).json({success: true}).end()
		BuilderInstance.log(`Manual build for ${server} triggered`)
		BuilderInstance.build(server, { fetchRepo: true })
	} catch(e) {
		console.error(e)
		res.status(500).json({error: e}).end()
	}
})

app.post('/switch-map', (req, res) => {
	const server = req.body.server
	const map = req.body.map
	if (!server) return res.status(400).json({error: "Missing server ID"})
	if (!map) return res.status(400).json({error: "Missing map"})
	try {
		BuilderInstance.setMapOverride(server, map)
		res.status(200).json({success: true}).end()
		BuilderInstance.build(server, { mapSwitch: true, skipCdn: true })
	} catch(e) {
		console.error(e)
		res.status(500).json({error: e}).end()
	}
})

app.listen(port, hostname, () => {
	console.log(`Server running at http://${hostname}:${port}/`)
})

setInterval(() => {
	BuilderInstance.run()
}, 2 * 1000 * 60)
