import sqlite3 from 'sqlite3'

class TestMerges {
	table = 'testmerges'

	constructor() {
		this.db = new sqlite3.Database('/app/db/testmerges.db', (err) => {
			if (err) {
				console.error('Failed to connect to test merge db', err)
				return
			}

			console.log('Connected to test merge db')
		})
	}

	getAll(server) {
		return new Promise((resolve, reject) => {
			let query = `SELECT * FROM ${this.table}`
			if (server) query += ' WHERE server = $server'
			return this.db.all(query, { $server: server }, (error, rows) => {
				if (error) return reject(error)
				return resolve(rows)
			})
		})
	}

	add(prId, serverId, requester, commit) {
		return new Promise((resolve, reject) => {
			return this.db.serialize(() => {
				this.db.get(
					`SELECT * FROM ${this.table} WHERE PR = $pr AND server = $server`,
					{ $pr: prId, $server: serverId },
					(error, row) => {
						if (error) return reject(error)
						if (row) return reject('That server already has that PR merged')
					}
				)

				this.db.run(
					`
					INSERT INTO ${this.table} (PR, server, requester, \`commit\`, created_at)
					VALUES ($pr, $server, $requester, $commit, datetime('now'))
					`,
					{
						$pr: prId,
						$server: serverId,
						$requester: requester,
						$commit: commit || null
					},
					(error) => {
						if (error) return reject(error)
						return resolve()
					}
				)
			})
		})
	}

	update(prId, serverId, updater, commit) {
		return new Promise((resolve, reject) => {
			return this.db.run(
				`
				UPDATE ${this.table}
				SET \`commit\` = $commit, updater = $updater, updated_at = datetime('now')
				WHERE PR = $pr AND server = $server
				`,
				{
					$commit: commit || null,
					$updater: updater,
					$pr: prId,
					$server: serverId
				},
				(error) => {
					if (error) return reject(error)
					return resolve()
				}
			)
		})
	}

	remove(prId, serverId) {
		return new Promise((resolve, reject) => {
			return this.db.run(
				`DELETE FROM ${this.table} WHERE PR = $pr AND server = $server`,
				{ $pr: prId, $server: serverId },
				(error) => {
					if (error) return reject(error)
					return resolve()
				}
			)
		})
	}
}

export default new TestMerges
