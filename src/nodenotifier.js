import https from 'https'
import config from '../config.js'

class NodeNotifier {
	constructor() {
		this.url = config.nodeNotifier.url
		this.user = config.nodeNotifier.user
		this.pass = config.nodeNotifier.pass
	}

	sendBuildComplete(map, payload) {
		if (!map || !this.pass) return
		if (payload.cancelled || payload.error) map = 'FAILED'

		const data = encodeURIComponent(`type=mapSwitchDone&map=${map}`)
		const options = {
		  host: this.url,
		  path: `/wiz/relay?server=${payload.server}&data=${data}`,
			auth: `${this.user}:${this.pass}`,
		  method: 'GET'
		}

		const req = https.request(options)
		req.on('error', error => {
		  console.error(error)
		})
		req.end()
	}
}

export default new NodeNotifier()
