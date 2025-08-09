package notifier

import (
	"embed"
	"fmt"

	"github.com/alitto/pond/v2"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/mailer"
)

// Notifier handles the sending of email notifications using a worker pool.
type Notifier struct {
	pool      pond.Pool
	pb        *pocketbase.PocketBase
	templates embed.FS
}

// EmailNotification represents an email to be sent to a user.
type EmailNotification struct {
	emailAddress string
	userID       string
	message      *mailer.Message
}

// TaskReminder contains information about a task.
type TaskReminder struct {
	taskName string
	daysLate int
}

// NewNotifier creates a new Notifier with the specified
// number of worker goroutines.
func NewNotifier(pb *pocketbase.PocketBase, templates embed.FS, numWorkers int) *Notifier {
	if numWorkers < 1 {
		pb.Logger().Warn("EMAIL reminders job",
			"status", "warning",
			"details", fmt.Sprintf("notifier launched with an invalid number of workers (%d), reverting to 10", numWorkers))
		numWorkers = 10
	}

	return &Notifier{
		pool:      pond.NewPool(numWorkers),
		pb:        pb,
		templates: templates,
	}
}

func (n *Notifier) NotifyUsers() {
	userSettings, err := n.allUserSettings()
	if err != nil {
		n.pb.Logger().Error(
			"EMAIL reminders job",
			"status", "failed",
			"error", err.Error(),
		)
		return
	}

	notificationEmails := n.constructNotificationEmails(userSettings)
	if len(notificationEmails) == 0 {
		return
	}

	if err := n.sendEmails(notificationEmails); err != nil {
		n.pb.Logger().Error(
			"EMAIL reminders job",
			"status", "failed",
			"error", err.Error(),
		)
		return
	}

	n.pb.Logger().Info(
		"EMAIL reminders job",
		"status", "success",
		"details", fmt.Sprintf("%d emails sent", len(notificationEmails)),
	)
}

func (n *Notifier) allUserSettings() ([]*core.Record, error) {
	return n.pb.FindRecordsByFilter("settings",
		"remindByEmailEnabled = true", "", 0, 0)
}
