import fs from 'fs'
import { exec } from 'child_process'
import treeKill from 'tree-kill'
import EventEmitter from 'events'
import config from '../config.js'
import { log, serversFolder } from './utils.js'
import Repo from './repo.js'
import MedAss from './medass.js'
import TestMerges from './testmerges.js'
import Metrics from './metrics.js'

const defaultOptions = {
	skipNotifier: false,
	skipCdn: false,
	switchToMap: null
}

export default class Build extends EventEmitter {
	mergeConflicts = []
	compileLog = null
	process = null
	cancelled = false
	startTime = null

	constructor(serverId, options) {
		super()
		this.serverId = serverId

		options = { ...defaultOptions, ...options }
		this.skipNotifier = options.skipNotifier
		this.skipCdn = options.skipCdn
		this.switchToMap = options.switchToMap

		this.Repo = new Repo(serverId)
		this.currentBranch = this.Repo.getBranch()
		this.testMergeBranch = `testmerge-${Date.now()}`
		this.serverFolder = `${serversFolder}/${serverId}`
	}

	setMapOverride(map) {
		fs.writeFileSync(`${this.serverFolder}/mapoverride`, map.toUpperCase())
	}

	cleanup() {
		this.Repo.checkout(this.currentBranch)
	}

	onFinishBuild(out, error) {
			// Grab the last compile log data and clean up after ourselves
			let lastCompileLogs = ''
			try {
				lastCompileLogs = fs.readFileSync(this.compileLog).toString().trim()
				fs.unlinkSync(this.compileLog)
			} catch (e) {}

			// Build an info object to inform external services of our status
			this.cleanup()
			const commit = this.Repo.getCurrentLocalHash()
			const payload = {
				server: this.serverId,
				last_compile: lastCompileLogs,
				branch: this.currentBranch,
				author: this.Repo.getAuthor(commit),
				message: this.Repo.getMessage(commit),
				mapSwitch: !!this.switchToMap,
				commit: commit,
				error: false,
				cancelled: false,
				mergeConflicts: this.mergeConflicts
			}

			const endTime = new Date().getTime()
			const duration = endTime - this.startTime

			if (this.cancelled) {
				log(`Building ${this.serverId} cancelled!`)
				payload.cancelled = true
				Metrics.insertBuild(this.serverId, duration, false, true, false)
			} else if (error) {
				log(`Building ${this.serverId} failed. Error:\n${error}`)
				if (typeof error === 'object') payload.error = true
				else payload.error = error
				Metrics.insertBuild(this.serverId, duration, false, false, false)
			} else {
				log(`Building ${this.serverId} succeeded! Output:\n${out}`)
				Metrics.insertBuild(this.serverId, duration, true, false, !!this.switchToMap)
			}

			if (!this.skipNotifier) MedAss.sendBuildComplete(payload)
			this.emit('complete', this.cancelled)
	}

	mergePrAtCommit(testMerge) {
		log(`Merging PR ${testMerge.PR} at commit ${testMerge.commit}`)
		const prBranch = `pr-${testMerge.PR}`

		// This fetches the PR and makes a new branch at the latest HEAD
		this.Repo.fetchPr(testMerge.PR)
		this.Repo.checkout(prBranch)

		if (testMerge.commit) {
			// Move the new PR branch to a specific commit if specified
			this.Repo.resetBranchToCommit(testMerge.commit)
		} else {
			// If no commit was specified, save whatever the latest HEAD commit is
			// This is so we don't always update to the latest on future merges, which introduces security risks
			const latestCommitHash = this.Repo.getCurrentLocalHash()
			TestMerges.update(testMerge.PR, testMerge.server, testMerge.updater, latestCommitHash)
		}

		// Move back to our primary test merge branch
		this.Repo.checkout(this.testMergeBranch)

		// Attempt to merge PR in, with handling to skip it if there are conflicts
		try {
			this.Repo.merge(prBranch)
		} catch (e) {
			this.mergeConflicts.push({ prId: testMerge.PR, files: this.Repo.getConflictedFiles() })
			this.Repo.abortMerge()
			return false
		}
		this.Repo.commit(`Testmerge ${prBranch}`)
		return true
	}

	async run() {
		this.startTime = new Date().getTime()
		// Pre-run steps
		this.Repo.fetch()
		this.Repo.update()
		if (this.switchToMap) this.setMapOverride(this.switchToMap)

		// Process test merges
		const successfulMergePrs = []
		const merges = await TestMerges.getAll(this.serverId)
		if (merges.length) {
			this.Repo.createAndCheckoutBranch(this.testMergeBranch)
			merges.forEach((merge) => {
				if (this.mergePrAtCommit(merge)) {
					successfulMergePrs.push(merge.PR)
				}
			})
		}

		this.compileLog = `/app/logs/builds/${this.serverId}-${Date.now()}.log`
		let cmd = `/bin/bash /app/scripts/gate.sh -s ${this.serverId} -b ${this.compileLog} -c ${config.github.token} -n ${this.currentBranch}`
		if (this.skipCdn) cmd += ' -r'
		if (successfulMergePrs.length) {
			cmd += ` -p ${successfulMergePrs.join(',')}`
		}

		if (this.cancelled) {
			this.onFinishBuild()
		} else {
			this.process = exec(cmd, (err, stdout, stderr) => {
				this.onFinishBuild(stdout, stderr || err)
			})
		}
	}

	cancel() {
		log(`Cancelling build for ${this.serverId}`)
		this.cancelled = true
		if (this.process) {
			treeKill(this.process.pid, 'SIGKILL')
		}
	}
}
