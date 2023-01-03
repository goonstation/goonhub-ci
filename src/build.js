import fs from 'fs'
import { exec } from 'child_process'
import EventEmitter from 'events'
import config from '../config.js'
import { log, serversFolder } from './utils.js'
import Repo from './repo.js'
import MedAss from './medass.js'
import TestMerges from './testmerges.js'

const defaultOptions = {
	skipNotifier: false,
	skipCdn: false,
	switchToMap: null
}

export default class Build extends EventEmitter {
	mergeConflicts = []

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

	mergePrAtCommit(prId, commit) {
		log(`Merging PR ${prId} at commit ${commit}`)
		const prBranch = `pr-${prId}`
		// This fetches the PR and makes a new branch at the latest HEAD
		this.Repo.fetchPr(prId)
		// Move the new PR branch to a specific commit if specified
		if (commit) {
			this.Repo.checkout(prBranch)
			this.Repo.resetBranchToCommit(commit)
			this.Repo.checkout(this.testMergeBranch)
		}
		try {
			this.Repo.merge(prBranch)
		} catch (e) {
			this.mergeConflicts.push({ prId, files: this.Repo.getConflictedFiles() })
			this.Repo.abortMerge()
			return false
		}
		this.Repo.commit(`Testmerge ${prBranch}`)
		return true
	}

	async run() {
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
				if (this.mergePrAtCommit(merge.PR, merge.commit)) {
					successfulMergePrs.push(merge.PR)
				}
			})
		}

		const compileLog = `/app/logs/builds/${this.serverId}-${Date.now()}.log`
		let cmd = `/bin/bash /app/scripts/gate.sh -s ${this.serverId} -b ${compileLog} -c ${config.github.token} -n ${this.currentBranch}`
		if (this.skipCdn) cmd += ' -r'
		if (successfulMergePrs.length) {
			cmd += ` -p ${successfulMergePrs.join(',')}`
		}
		exec(cmd, (err, stdout, stderr) => {
			// Grab the last compile log data and clean up after ourselves
			let lastCompileLogs = ''
			try {
				lastCompileLogs = fs.readFileSync(compileLog).toString().trim()
				fs.unlinkSync(compileLog)
			} catch (e) {}

			// Build an info object to inform external services of our status
			const commit = this.Repo.getCurrentLocalHash()
			const payload = {
				server: this.serverId,
				last_compile: lastCompileLogs,
				branch: this.currentBranch,
				author: this.Repo.getAuthor(commit),
				message: this.Repo.getMessage(commit),
				mapSwitch: !!this.switchToMap,
				commit: commit,
				error: null,
				mergeConflicts: this.mergeConflicts
			}

			if (err || stderr) {
				log(`Building ${this.serverId} failed. Error: ${err}. Stderr: ${stderr}`)
				payload.error = stderr || true
			} else {
				log(`Building ${this.serverId} succeeded! Output:\n${stdout}`)
			}

			if (!this.skipNotifier) MedAss.sendBuildComplete(payload)
			this.Repo.checkout(this.currentBranch)
			this.emit('complete')
		})
	}
}
