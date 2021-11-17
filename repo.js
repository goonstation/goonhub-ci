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
}
