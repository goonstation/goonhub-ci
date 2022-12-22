import { execSync } from 'child_process'

export default class Repo {
	static fetch(dir) {
		return execSync('git fetch -q --recurse-submodules', { cwd: dir }).toString()
	}

	static getCurrentLocalHash(dir) {
		return execSync('git rev-parse @', { cwd: dir }).toString()
	}

	static getLatestOriginHash(dir) {
		return execSync('git rev-parse @{u}', { cwd: dir }).toString()
	}

	static update(dir) {
		return execSync('git reset -q --recurse-submodules --hard @{u}', { cwd: dir }).toString()
	}

	static getBranch(dir) {
		return execSync('git rev-parse --abbrev-ref HEAD', { cwd: dir }).toString()
	}

	static getAuthor(dir, commit) {
		return execSync(`git log --format="%an" -n 1 ${commit}`, { cwd: dir }).toString()
	}

	static getMessage(dir, commit) {
		return execSync(`git log --format="%B" -n 1 ${commit}`, { cwd: dir }).toString()
	}

	static doesBranchExist(dir, branch) {
		return execSync(`git ls-remote --heads origin ${branch} | wc -l`, { cwd: dir }).toString()
	}

	static checkout(dir, branch) {
		return execSync(`git checkout -q --recurse-submodules ${branch}`, { cwd: dir }).toString()
	}

	static clean(dir) {
		return execSync(`git clean -fd`, { cwd: dir }).toString()
	}
}
