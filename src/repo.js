import fs from 'fs'
import { execSync } from 'child_process'
import { serversFolder } from './utils.js'

export default class Repo {
	constructor(serverId) {
		this.serverId = serverId
		this.folder = `${serversFolder}/${serverId}/repo`
		if (!fs.existsSync(this.folder)) {
			throw new Error(`Unable to locate repo folder for server ${serverId}`)
		}
	}

	run(cmd) {
		return execSync(cmd, { cwd: this.folder }).toString().trim()
	}

	fetch() {
		return this.run('git fetch -q --recurse-submodules')
	}
	fetchPr(prId) {
		return this.run(`git fetch origin pull/${prId}/head:pr-${prId}`)
	}
	getCurrentLocalHash() {
		return this.run('git rev-parse @')
	}
	getLatestOriginHash() {
		return this.run('git rev-parse @{u}')
	}
	update() {
		return this.run('git reset -q --recurse-submodules --hard @{u}')
	}
	getBranch() {
		return this.run('git rev-parse --abbrev-ref HEAD')
	}
	getAuthor(commit) {
		return this.run(`git log --format="%an" -n 1 ${commit}`)
	}
	getMessage(commit) {
		return this.run(`git log --format="%B" -n 1 ${commit}`)
	}
	doesBranchExist(branch) {
		return this.run(`git ls-remote --heads origin ${branch} | wc -l`)
	}
	createAndCheckoutBranch(branch) {
		return this.run(`git checkout -q --recurse-submodules -b ${branch}`)
	}
	checkout(branch) {
		return this.run(`git checkout -q --recurse-submodules ${branch}`)
	}
	clean() {
		return this.run(`git clean -fd`)
	}
	resetBranchToCommit(commit) {
		return this.run(`git reset -q --recurse-submodules --hard ${commit}`)
	}
	merge(branch) {
		return this.run(`git merge --no-commit --no-ff ${branch}`)
	}
	abortMerge() {
		return this.run('git merge --abort')
	}
	getConflictedFiles() {
		return this.run('git diff --name-only --diff-filter=U --relative')
	}
	commit(message) {
		return this.run(`git commit -m "${message}"`)
	}
	deleteTestMergeBranches() {
		return this.run(`git branch | grep "testmerge-*" | xargs git branch -D`)
	}
}
