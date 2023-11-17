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
				CREATE TABLE IF NOT EXISTS "builds" (
					"server"	TEXT,
					"duration"	INTEGER,
					"success"	INTEGER,
					"cancelled"	INTEGER,
					"map_switch" INTEGER,
					"timestamp"	DATETIME DEFAULT CURRENT_TIMESTAMP
				)
			`)
		})
	}

	insertBuild(server, duration, success, cancelled, mapSwitch) {
		return new Promise((resolve, reject) => {
			return this.db.run(
				`
				INSERT INTO builds (server, duration, success, cancelled, map_switch)
				VALUES ($server, $duration, $success, $cancelled, $map_switch)
				`,
				{
					$server: server,
					$duration: duration,
					$success: success,
					$cancelled: cancelled,
					$map_switch: mapSwitch
				},
				(error) => {
					if (error) return reject(error)
					return resolve()
				}
			)
		})
	}

	getBuildMetrics() {
		return new Promise((resolve, reject) => {
			return this.db.get(`
				SELECT
					(SELECT count(*) FROM builds WHERE success = 1) AS successful_builds,
					(SELECT count(*) FROM builds WHERE success = 0) AS failed_builds,
					(SELECT count(*) FROM builds WHERE cancelled = 1) AS cancelled_builds,
					(SELECT count(*) FROM builds WHERE map_switch = 1) AS map_switch_builds,
					(SELECT avg(duration) FROM builds WHERE success = 1) AS average_build_duration
				FROM builds
			`, (error, row) => {
				if (error) return reject(error)
				return resolve(row)
			})
		})
	}
}

export default new Metrics
