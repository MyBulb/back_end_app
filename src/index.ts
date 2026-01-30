import dotenv from "dotenv";
import http from "http";
import { createApp } from "./configServer";
import { EnumColorText } from "./lib/colorText";
import { setupWebSocket } from "./webSocket";

dotenv.config();

const app = createApp();
const server = http.createServer(app);

setupWebSocket(server);

const PORT = Number(process.env.PORT ?? 3000);

server.listen(PORT, () => {
	console.info(
		`${EnumColorText.GREEN}HTTP server listening on http://localhost:${PORT}${EnumColorText.RESET}`,
	);
	console.info(
		`${EnumColorText.GREEN}WebSocket available on ws://localhost:${PORT}/ws${EnumColorText.RESET}`,
	);
});
