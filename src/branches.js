import Repo from './repo.js'

export default class Branch {
	static getBranch(serverId) {
		const repo = new Repo(serverId)
		return repo.getBranch()
	}

	static switchBranch(serverId, branch) {
		const repo = new Repo(serverId)
		repo.fetch()
		if (repo.doesBranchExist(branch) === '0') {
			throw new Error('That branch does not exist')
		}
		repo.checkout(branch)
		repo.clean()
		repo.update()
	}
}
