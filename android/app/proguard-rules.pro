# WorkManager creates its Room database by class name and looks up this
# generated no-argument constructor through reflection during app startup.
-keep class androidx.work.impl.WorkDatabase_Impl { public <init>(); *; }

# WorkManager instantiates application workers by their class names.
-keep class ru.kopi.kopi_finance_app.PaymentReminderWorker { *; }
-keep class ru.kopi.kopi_finance_app.NotificationUploadWorker { *; }
