package main

import (
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

// disableHealthRouteLogging disables logging of successful requests
// hitting the /api/health endpoint from user agent "Wget".
// This prevents Docker Compose from polluting the logs with
// constant healthcheck pings.
func (app *application) disableHealthRouteLogging() {
	app.pb.OnServe().BindFunc(func(se *core.ServeEvent) error {
		se.Router.BindFunc(func(re *core.RequestEvent) error {
			if re.Request.URL.Path == "/api/health" && re.Request.UserAgent() == "Wget" {
				return apis.SkipSuccessActivityLog().Func(re)
			}
			return re.Next()
		})

		return se.Next()
	})
}
