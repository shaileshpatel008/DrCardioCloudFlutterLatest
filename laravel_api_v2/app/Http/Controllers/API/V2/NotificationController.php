<?php

namespace App\Http\Controllers\API\V2;

use App\Http\Controllers\NotificationController as WebNotificationController;
use Illuminate\Http\Request;

/** Bell notifications (cardiologists get "New ECG Report Uploaded"). */
class NotificationController extends ApiController
{
    /** GET /api/v2/notifications — latest 10 unread + unread total (same as /notification). */
    public function index()
    {
        $payload = app(WebNotificationController::class)->index()->getData(true);

        return $this->ok(
            collect($payload['data'] ?? [])->map(fn ($n) => [
                'id' => $n['id'],
                'title' => $n['title'],
                'date' => $n['date'] ?? null,
                'created_at' => $this->iso($n['created_at'] ?? null),
            ])->values(),
            null,
            ['unread_total' => (int) ($payload['total_data'] ?? 0)]
        );
    }

    /** POST /api/v2/notifications/{id}/read */
    public function read(Request $request, int $id)
    {
        $request->merge(['id' => $id]);
        app(WebNotificationController::class)->readNotification($request);

        return $this->ok(null, 'Notification marked as read.');
    }

    /** POST /api/v2/notifications/read-all */
    public function readAll(Request $request)
    {
        app(WebNotificationController::class)->readAllNotification($request);

        return $this->ok(null, 'All notifications marked as read.');
    }
}
