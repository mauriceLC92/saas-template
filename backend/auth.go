package main

import (
	"github.com/pocketbase/pocketbase/core"
)

// setupAuthHooks configures the application's authentication-related hooks.
// When a new user is created, a new settings record is created for them.
// When a user logs in with password for the first time, the flag
// authWithPasswordAvailable is set to true.
func (app *application) setupAuthHooks() {
	app.pb.OnModelAfterCreateSuccess("users").
		BindFunc(func(e *core.ModelEvent) error {
			record := e.Model.(*core.Record)
			userId := record.Id

			settingsCollection, err := app.pb.FindCollectionByNameOrId("settings")
			if err != nil {
				return err
			}

			newSettingsRecord := core.NewRecord(settingsCollection)
			newSettingsRecord.Set("user", userId)
			newSettingsRecord.Set("remindEmail", record.GetString("email"))
			newSettingsRecord.Set("remindByEmailEnabled", false)
			newSettingsRecord.Set("theme", "system")

			app.pb.Save(newSettingsRecord)

			return e.Next()
		})

	app.pb.OnRecordAuthWithPasswordRequest().
		BindFunc(func(e *core.RecordAuthWithPasswordRequestEvent) error {
			userRecord := e.Record

			if isAvailable := userRecord.GetBool("authWithPasswordAvailable"); !isAvailable {
				userRecord.Set("authWithPasswordAvailable", true)
				app.pb.Save(userRecord)
			}

			return e.Next()
		})
}
