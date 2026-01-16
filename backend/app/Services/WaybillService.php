<?php

namespace App\Services;

use App\Models\Order;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Support\Facades\Storage;

class WaybillService
{
    /**
     * Generate waybill PDF for an order
     *
     * @param Order $order
     * @return string Path to the generated PDF
     */
    public function generateWaybill(Order $order): string
    {
        // Load relationships
        $order->load(['user', 'orderItems.product', 'driver']);

        // Generate PDF from view
        $pdf = Pdf::loadView('pdfs.waybill', [
            'order' => $order,
        ]);

        // Set paper size and orientation
        $pdf->setPaper('a4', 'portrait');

        // Create filename with order code and timestamp
        $filename = 'waybill_' . $order->order_code . '_' . time() . '.pdf';
        $path = 'waybills/' . $filename;

        // Save to public storage
        Storage::disk('public')->put($path, $pdf->output());

        return $path;
    }

    /**
     * Delete old waybill if exists
     *
     * @param string|null $oldPath
     * @return void
     */
    public function deleteOldWaybill(?string $oldPath): void
    {
        if ($oldPath && Storage::disk('public')->exists($oldPath)) {
            Storage::disk('public')->delete($oldPath);
        }
    }
}
