import sqlite3 from 'sqlite3'

class Metrics {
	constructor() {
		this.db = new sqlite3.Database('db/metrics.db', (err) => {
			if (err) {
				console.error('Failed to connect to metrics db', err)
				return
			}

			console.log('Connected to metrics db')

			this.db.run(`
				CREATE TABLE IF NOT EXISTS "build_durations" (
					"server"	TEXT,
					"duration"	INTEGER
				)
			`)
			this.db.run(`
				CREATE TABLE IF NOT EXISTS "metrics" (
					"type"	TEXT,
					"amount"	INTEGER
				)
			`)
		})
	}

	getAll() {
		return new Promise((resolve, reject) => {
			let query = `SELECT * FROM metrics`
			return this.db.all(query, (error, rows) => {
				if (error) return reject(error)
				return resolve(rows)
			})
		})
	}

	getAverageBuildDuration() {
		return new Promise((resolve, reject) => {
			return this.db.get(`SELECT avg(duration) AS average_duration FROM build_durations`, (error, row) => {
				if (error) return reject(error)
				return resolve(row)
			})
		})
	}

	increment(type) {
		return new Promise((resolve, reject) => {
			return this.db.run(
				`
				UPDATE metrics
				SET amount = amount + 1
				WHERE type = $type
				`,
				{
					$type: type
				},
				(error) => {
					if (error) return reject(error)
					return resolve()
				}
			)
		})
	}

	addBuildDuration(server, duration) {
		return new Promise((resolve, reject) => {
			return this.db.run(
				`
				INSERT INTO build_durations (server, duration) VALUES ($server, $duration)
				`,
				{
					$server: server,
					$duration: duration
				},
				(error) => {
					if (error) return reject(error)
					return resolve()
				}
			)
		})
	}
}

export default new Metrics
