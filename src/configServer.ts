import cors from "cors";
import express from "express";
import routes from "./routes";

export function createApp() {
	const app = express();

	// CORS minimal (à adapter)
	const allowedOrigins = process.env.FRONTEND_URL || "";

	app.use(
		cors({
			origin(origin, cb) {
				// Autorise les requêtes sans origin (ex: curl, server-to-server)
				if (!origin) return cb(null, true);

				if (allowedOrigins.includes(origin)) return cb(null, true);
				return cb(new Error("Not allowed by CORS"));
			},
			credentials: true, // si tu utilises cookies / auth
			methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
			allowedHeaders: ["Content-Type", "Authorization"],
		}),
	);

	app.use(express.json({ limit: "1mb" }));

	app.use(routes);

	return app;
}
