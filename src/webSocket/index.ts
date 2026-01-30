import type { Server as HttpServer } from "http";
import { WebSocketServer } from "ws";
import { EnumColorText } from "../lib/colorText";

export function setupWebSocket(server: HttpServer) {
	const wss = new WebSocketServer({ server, path: "/ws" });

	wss.on("connection", (socket, req) => {
		console.info(
			`${EnumColorText.GREEN}WS connected:${req.socket.remoteAddress}${EnumColorText.RESET}`,
		);

		socket.on("close", () => {
			console.info(`${EnumColorText.RED}WS disconnected${EnumColorText.RESET}`);
		});
	});

	return wss;
}
