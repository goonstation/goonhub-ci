import express from 'express'
import fs from 'fs'
import config from './config.js'
import Runner from './src/runner.js'
import Branches from './src/branches.js'
import TestMerges from './src/testmerges.js'
import { log, serverConfig } from './src/utils.js'

const hostname = '0.0.0.0'
const port = 3000

const app = express()
app.use(express.json())

const RunnerInstance = new Runner

app.use((req, res, next) => {
	if (req.header('Api-Key') === config.apiKey) next()
	else res.status(401).send('No.')
})

app.get('/status', (req, res) => {
	res.json({
		maxCompileJobs: RunnerInstance.maxJobs,
		currentCompileJobs: RunnerInstance.currentJobs,
		queuedJobs: RunnerInstance.queuedJobs.map(e => e.server)
	}).end()
})

app.get('/branch/:server', (req, res) => {
	const server = req.params.server
	if (!server) return res.status(400).json({error: 'Missing server ID'})
	try {
		res.status(200).json({ branch: Branches.getBranch(server) })
	} catch(e) {
		res.status(500).json({error: e.message})
	}
})

app.post('/switch-branch', (req, res) => {
	const server = req.body.server
	const branch = req.body.branch
	if (!server) return res.status(400).json({error: 'Missing server ID'})
	if (!branch) return res.status(400).json({error: 'Missing branch'})

	if (RunnerInstance.currentJobs.includes(server)) {
		res.status(400).json({error: 'Unable to switch the branch of a server that is currently building'})
		return
	}

	try {
		Branches.switchBranch(server, branch)
		res.status(200).json({success: true})
	} catch(e) {
		res.status(500).json({error: e.message})
	}
})

app.post('/build', (req, res) => {
	const server = req.body.server
	if (!server) return res.status(400).json({error: 'Missing server ID'})
	try {
		res.status(200).json({success: true}).end()
		log(`Manual build for ${server} triggered`)
		RunnerInstance.build(server)
	} catch(e) {
		log(e)
		// res.status(500).json({error: e.message})
	}
})

app.post('/cancel', (req, res) => {
	const server = req.body.server
	if (!server) return res.status(400).json({error: 'Missing server ID'})
	try {
		res.status(200).json({success: true}).end()
		log(`Manual cancel for ${server} triggered`)
		const Build = RunnerInstance.getBuildByServerId(server)
		if (Build) Build.cancel()
	} catch(e) {
		log(e)
		// res.status(500).json({error: e.message})
	}
})

app.post('/switch-map', (req, res) => {
	const server = req.body.server
	const map = req.body.map
	if (!server) return res.status(400).json({error: 'Missing server ID'})
	if (!map) return res.status(400).json({error: 'Missing map'})
	try {
		res.status(200).json({success: true}).end()
		RunnerInstance.build(server, { switchToMap: map, skipCdn: true })
	} catch(e) {
		log(e)
		// res.status(500).json({error: e.message})
	}
})

app.post('/restart', (req, res) => {
	const server = req.body.server
	if (!server) return res.status(400).json({error: 'Missing server ID'})
	try {
		const servers = serverConfig.servers
		let valid = false
		for (const cServer in servers) {
			const settings = servers[cServer]
			if (cServer === server && settings.active) {
				valid = true
				break
			}
		}
		if (!valid) return res.status(400).json({error: 'Invalid server ID'})
		fs.closeSync(fs.openSync(`/remote_ss13/restarter/triggers/${server}`, 'w'))
		res.status(200).json({success: true})
	} catch(e) {
		res.status(500).json({error: e.message})
	}
})

app.get('/test-merges/:server?', async (req, res) => {
	const server = req.params.server
	try {
		const allTestMerges = await TestMerges.getAll(server)
		res.status(200).json(allTestMerges)
	} catch (e) {
		res.status(500).json({error: e.message})
	}
})

app.post('/test-merges', async (req, res) => {
	const pr = req.body.pr
	const server = req.body.server
	const requester = req.body.requester
	const commit = req.body.commit
	if (!pr) return res.status(400).json({error: 'Missing PR ID'})
	if (!server) return res.status(400).json({error: 'Missing server ID'})
	try {
		await TestMerges.add(pr, server, requester, commit)
		res.status(200).json({success: true})
	} catch (e) {
		res.status(500).json({error: e.message})
	}
})

app.put('/test-merges', async (req, res) => {
	const pr = req.body.pr
	const server = req.body.server
	const updater = req.body.updater
	const commit = req.body.commit
	if (!pr) return res.status(400).json({error: 'Missing PR ID'})
	if (!server) return res.status(400).json({error: 'Missing server ID'})
	try {
		await TestMerges.update(pr, server, updater, commit)
		res.status(200).json({success: true})
	} catch (e) {
		res.status(500).json({error: e.message})
	}
})

app.delete('/test-merges', async (req, res) => {
	const pr = req.body.pr
	const server = req.body.server
	if (!pr) return res.status(400).json({error: 'Missing PR ID'})
	if (!server) return res.status(400).json({error: 'Missing server ID'})
	try {
		await TestMerges.remove(pr, server)
		res.status(200).json({success: true})
	} catch (e) {
		res.status(500).json({error: e.message})
	}
})

app.listen(port, hostname, () => {
	console.log(`Server running at https://${hostname}:${port}/`)
})

setInterval(() => {
	RunnerInstance.run()
}, 2 * 1000 * 60)
