<?php

namespace App\Http\Controllers\API\V2\Concerns;

use Illuminate\Http\Request;

/**
 * The web controllers read checkboxes the HTML way: the field is either
 * "1" or missing (several use is_null() checks). The app sends real
 * booleans, so turn true into "1" and drop false before delegating.
 */
trait NormalizesCheckboxes
{
    protected function normalizeCheckboxes(Request $request, array $fields): void
    {
        foreach ($fields as $field) {
            if (! $request->exists($field)) {
                continue;
            }
            $value = $request->input($field);
            $on = in_array($value, [true, 1, '1', 'true', 'on', 'yes'], true);
            if ($on) {
                $request->merge([$field => '1']);
            } else {
                $request->request->remove($field);
                $request->query->remove($field);
                if ($request->isJson()) {
                    $request->json()->remove($field);
                }
            }
        }
    }
}
