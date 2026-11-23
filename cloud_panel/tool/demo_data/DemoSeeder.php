<?php

namespace Database\Seeders;

use App\Models\Cardiologist;
use App\Models\Client;
use App\Models\ClientCardiologist;
use App\Models\ClientStaff;
use App\Models\Device;
use App\Models\Notification;
use App\Models\PdfData;
use App\Models\Role;
use App\Models\Template;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Crypt;

/** Fictional demo data for the client presentation build. Local only. */
class DemoSeeder extends Seeder
{
    private function role(string $name): Role
    {
        return Role::firstOrCreate(['name' => $name]);
    }

    private function user(string $name, string $email, string $role, string $phone, array $extra = []): User
    {
        $u = new User();
        $u->name = $name;
        $u->email = $email;
        $u->password = Crypt::encryptString('Demo@123');
        $u->phone_number = $phone;
        if (isset($extra['oem'])) {
            $u->oem_access = 1;
        }
        $u->created_at = $extra['created'] ?? Carbon::now()->subMonths(5);
        $u->updated_at = $extra['created'] ?? Carbon::now()->subMonths(5);
        $u->save();
        $u->roles()->attach($this->role($role)->id);

        return $u;
    }

    public function run(): void
    {
        mt_srand(2026);
        foreach (['admin', 'sub_admin', 'client', 'staff', 'cardiologist'] as $r) {
            $this->role($r);
        }

        $this->user('Super Admin', 'admin@example.com', 'admin', '9638389333');
        $oem = $this->user('MedPoint Distributors', 'oem@example.com', 'sub_admin', '9825048204', ['oem' => true]);

        // Cardiologists: [name, email, city, owner, footer]
        $cardioDefs = [
            ['Dr. Ananya Rao', 'cardio@example.com', 'Bengaluru, Karnataka', 0, 'MD, DM (Cardiology) · Consultant Cardiologist'],
            ['Dr. Vikram Shah', 'vikram.shah@example.com', 'Ahmedabad, Gujarat', 0, 'MD, DNB (Cardiology)'],
            ['Dr. Meera Iyer', 'meera.iyer@example.com', 'Chennai, Tamil Nadu', 0, 'MD, DM (Cardiology)'],
            ['Dr. Rohan Kapoor', 'rohan.kapoor@example.com', 'New Delhi, Delhi', 0, 'MD (Medicine), DM (Cardiology)'],
            ['Dr. Rakesh Ola', 'rakesh.ola@example.com', 'Jaipur, Rajasthan', $oem->id, 'MD, DM (Cardiology)'],
        ];
        $cardios = [];
        foreach ($cardioDefs as $i => [$name, $email, $city, $owner, $footer]) {
            $u = $this->user($name, $email, 'cardiologist', '98250'.(15000 + $i * 1371));
            Cardiologist::insert(['user_id' => $u->id, 'address' => $city, 'parent_user_id' => $owner, 'footer' => $footer, 'created_at' => now()->subMonths(5), 'updated_at' => now()->subMonths(5)]);
            $cardios[] = $u;
            Template::insert([
                ['title' => 'Normal sinus rhythm', 'body' => '<p>Normal sinus rhythm.</p><p>No acute ST-T changes.</p>', 'cardiologist_id' => $u->id, 'created_at' => now(), 'updated_at' => now()],
                ['title' => 'Sinus tachycardia', 'body' => '<p>Sinus tachycardia.</p><ul><li>Correlate clinically</li><li>Repeat ECG if symptomatic</li></ul>', 'cardiologist_id' => $u->id, 'created_at' => now(), 'updated_at' => now()],
                ['title' => 'Sinus bradycardia', 'body' => '<p>Sinus bradycardia.</p><ul><li>Review medication (beta blockers)</li><li>Holter monitoring if dizziness</li></ul>', 'cardiologist_id' => $u->id, 'created_at' => now(), 'updated_at' => now()],
                ['title' => 'LVH with strain', 'body' => '<p>Left ventricular hypertrophy with strain pattern.</p><ul><li>2D Echo advised</li><li>Control blood pressure</li></ul>', 'cardiologist_id' => $u->id, 'created_at' => now(), 'updated_at' => now()],
            ]);
        }

        // Clients: [hospital, email, doctor, address, lat, lng, owner, cardiologist index|null, limit on, limit, multi]
        $clientDefs = [
            ['Sunrise Diagnostics', 'client@example.com', 'Dr. Nikhil Shah', 'Navrangpura, Ahmedabad, Gujarat 380009', '23.0365', '72.5611', 0, 0, 1, 500, 0],
            ['CityCare Hospital', 'citycare@example.com', 'Dr. Sana Khan', 'Andheri East, Mumbai, Maharashtra 400069', '19.1136', '72.8697', 0, null, 0, 0, 1],
            ['Lotus Heart Clinic', 'lotus@example.com', 'Dr. Aditi Joshi', 'Kothrud, Pune, Maharashtra 411038', '18.5074', '73.8077', 0, 0, 0, 0, 0],
            ['GreenValley Hospital', 'greenvalley@example.com', 'Dr. Karthik Menon', 'Jayanagar, Bengaluru, Karnataka 560041', '12.9308', '77.5838', 0, 2, 1, 300, 0],
            ['Shree Krishna Nursing Home', 'shreekrishna@example.com', 'Dr. Paresh Desai', 'Adajan, Surat, Gujarat 395009', '21.1959', '72.7933', 0, 1, 0, 0, 0],
            ['Riverside Medical Centre', 'riverside@example.com', 'Dr. Leela Nair', 'Edappally, Kochi, Kerala 682024', '10.0261', '76.3125', 0, 3, 0, 0, 0],
            ['Medilab Diagnostic Centre', 'medilab@example.com', 'Dr. Asha Pillai', 'C-Scheme, Jaipur, Rajasthan 302001', '26.9124', '75.7873', $oem->id, 4, 1, 200, 0],
            ['Arogya Polyclinic', 'arogya@example.com', 'Dr. Manish Jain', 'Hiran Magri, Udaipur, Rajasthan 313002', '24.5854', '73.7125', $oem->id, 4, 0, 0, 0],
        ];
        $staffNames = [
            ['Rahul Verma', 'Priya Nair', 'Kiran Solanki'], ['Ayesha Khan', 'Vivek Rao'], ['Sneha Kulkarni', 'Amit Deshmukh'],
            ['Divya Hegde', 'Naveen Kumar', 'Sahana Rao'], ['Hetal Patel', 'Jignesh Modi'], ['Anjali Thomas', 'Joseph Mathew'],
            ['Sunil Sharma', 'Neha Choudhary'], ['Pankaj Mehta', 'Ritu Agarwal'],
        ];
        $patients = ['Ramesh Kulkarni', 'Sunita Patil', 'Arjun Mehta', 'Fatima Shaikh', 'Mohan Lal', 'Kavya Reddy', 'Imran Qureshi', 'Lakshmi Iyer',
            'Deepak Singh', 'Pooja Bhatt', 'Suresh Pillai', 'Meena Joshi', 'Harpreet Kaur', 'Anil Gupta', 'Rekha Menon', 'Vijay Chauhan',
            'Nasreen Begum', 'Prakash Rao', 'Geeta Sharma', 'Ravi Shankar', 'Shalini Das', 'Gopal Krishnan', 'Zoya Ansari', 'Manoj Tiwari',
            'Usha Nambiar', 'Rajesh Khanna', 'Bhavna Shah', 'Sameer Kulkarni', 'Anita Fernandes', 'Kishore Patel', 'Farhan Siddiqui', 'Lata Deshpande'];
        $reports = [
            ['normal', '<p>Normal sinus rhythm.</p><p>No acute ST-T changes.</p>', [62, 92]],
            ['normal', '<p>Sinus rhythm within normal limits.</p><p>Normal axis. No ST-T changes.</p>', [64, 88]],
            ['normal', '<p>Normal sinus rhythm.</p><p>Normal PR and QRS intervals. No ischaemic changes.</p>', [66, 90]],
            ['normal', '<p>Sinus rhythm, normal ECG.</p><p>Routine follow-up.</p>', [60, 84]],
            ['abnormal', '<p>Sinus tachycardia.</p><ul><li>Correlate clinically</li><li>Repeat ECG if symptomatic</li></ul>', [102, 118]],
            ['abnormal', '<p>Sinus bradycardia.</p><ul><li>Review medication (beta blockers)</li><li>Holter monitoring if dizziness</li></ul>', [46, 56]],
            ['abnormal', '<p>Left ventricular hypertrophy with strain pattern.</p><ul><li>2D Echo advised</li><li>Control blood pressure</li></ul>', [70, 86]],
            ['abnormal', '<p>T-wave inversion in V4–V6.</p><ul><li>Rule out ischaemia: Troponin I</li><li>Cardiology OPD review within 24 hours</li></ul>', [72, 94]],
        ];
        $models = [['vivo 1907', 'vivo vivo 1907'], ['SM-A515F', 'samsung Galaxy A51'], ['RMX3085', 'realme 8'], ['M2101K7BI', 'Xiaomi Redmi Note 10']];

        $n = 0;
        foreach ($clientDefs as $i => [$hospital, $email, $doctor, $address, $lat, $lng, $owner, $cIdx, $limitOn, $limit, $multi]) {
            $created = Carbon::now()->subMonths(4)->subDays($i * 6);
            $u = $this->user($hospital, $email, 'client', '98250'.(30000 + $i * 2311), ['created' => $created]);
            $c = new Client();
            $c->user_id = $u->id;
            $c->hospital_name = $hospital;
            $c->address = $address;
            $c->doctor_name = $doctor;
            $c->parent_user_id = $owner;
            $c->report_limit_enabled = $limitOn;
            $c->report_limit = $limit;
            $c->multi_hospital_access = $multi;
            $c->webhook_url = $i === 0 ? 'https://his.example.com/ecg/webhook' : null;
            $c->get_patient_api_enabled = 0;
            $c->get_patient_url = '';
            $c->created_at = $created;
            $c->updated_at = $created;
            $c->save();
            $cardioId = $cIdx === null ? null : $cardios[$cIdx]->id;
            if ($cardioId) {
                $link = new ClientCardiologist();
                $link->client_id = $u->id;
                $link->cardiologist_id = $cardioId;
                $link->save();
            }

            $devices = [];
            for ($d = 0; $d < 2; $d++) {
                $dev = new Device();
                $dev->client_id = $c->id;
                $dev->intrument_id = sprintf('Dr.Cardio/%d-%04d', 2410 + $i * 3 + $d, 1000 + ($i * 7919 + $d * 104729) % 9000);
                $dev->save();
                $devices[] = $dev;
            }
            $staff = [];
            foreach ($staffNames[$i] as $name) {
                $su = $this->user($name, strtolower(str_replace(' ', '.', $name)).'@example.com', 'staff', '9'.mt_rand(700000000, 999999999), ['created' => $created]);
                $cs = new ClientStaff();
                $cs->client_id = $c->id;
                $cs->staff_id = $su->id;
                $cs->save();
                $staff[] = $su;
            }

            // ECG traffic over the last 30 days; the busiest clients get more.
            $count = [34, 22, 18, 26, 16, 14, 20, 12][$i];
            $slug = strtolower(str_replace(' ', '_', $hospital));
            for ($k = 0; $k < $count; $k++, $n++) {
                $daysAgo = (int) floor(pow($k / $count, 1.2) * 30);
                $when = $daysAgo === 0
                    ? Carbon::now()->subMinutes(9 + (($k * 53 + $i * 31) % 420))->setSecond(mt_rand(0, 59))
                    : Carbon::now()->subDays($daysAgo)->setTime(8 + mt_rand(0, 11), mt_rand(0, 59), mt_rand(0, 59));
                $st = $staff[$k % count($staff)];
                $dev = $devices[$k % 2];
                $patient = $patients[($n * 7 + $i) % count($patients)];
                $file = str_replace(' ', '_', $patient).'_'.$when->format('Y-m-d_H-i-s').'.pdf';

                // Recent ECGs are still in progress; older ones are mostly reported.
                if ($daysAgo === 0) {
                    $status = ['requested', 'pending', 'requested', 'reported', 'requested'][$k % 5];
                } elseif ($daysAgo <= 3) {
                    $status = ['requested', 'reported', 'pending', 'requested', 'reported', 'reported'][$k % 6];
                } else {
                    $status = ['reported', 'reported', 'reported', 'pending', 'reported', 'no_credit', 'reported'][$k % 7];
                }
                if (! $cardioId && in_array($status, ['requested', 'reported', 'no_credit'])) {
                    $status = 'pending';
                }

                $p = new PdfData();
                $p->device_id = $dev->id;
                $p->staff_id = $st->id;
                $p->pdf = $file;
                $p->original_file_name = $file;
                $p->csv_file_name = str_replace('.pdf', '.csv', $file);
                $p->document_slug = $slug;
                $p->latitude = (string) round((float) $lat + mt_rand(-80, 80) / 10000, 4);
                $p->longitude = (string) round((float) $lng + mt_rand(-80, 80) / 10000, 4);
                $p->address = preg_replace('/\s\d{6}$/', '', $address);
                [$model, $full] = $models[$k % count($models)];
                $p->device_info = json_encode(['Model' => $model, 'FullDeviceInfo' => $full]);
                $p->patient_info = json_encode(['Name' => $patient, 'Age' => (string) mt_rand(24, 81), 'Gender' => (($n * 7 + $i) % 2) ? 'Female' : 'Male', 'Id' => 'P'.(24000 + $n)]);
                $p->status = $status;
                if (in_array($status, ['requested', 'reported']) && $cardioId) {
                    $p->cardiologist_id = $cardioId;
                    $p->requested_time = $when->copy()->addMinutes(mt_rand(1, 6));
                }
                if ($status === 'reported') {
                    [$ecg, $body, [$lo, $hi]] = $reports[($k * 5 + $i) % count($reports)];
                    $hr = mt_rand($lo, $hi);
                    $qt = mt_rand(340, 410);
                    $qtc = (int) round($qt / sqrt(60 / $hr));
                    $reported = $when->copy()->addMinutes(mt_rand(8, 95));
                    if ($reported->isFuture()) {
                        $reported = Carbon::now()->subMinutes(2);
                    }
                    $p->reported_time = $reported;
                    $p->ecg_status = $ecg;
                    $p->hr = (string) $hr;
                    $p->r = number_format(mt_rand(8, 18) / 10, 1);
                    $p->rr = (string) (int) round(60000 / $hr);
                    $p->pr = (string) mt_rand(130, 190);
                    $p->qrs = (string) mt_rand(80, 108);
                    $p->qt = (string) $qt;
                    $p->qtc = (string) $qtc;
                    $p->qt_by_qtc = number_format($qt / $qtc, 2);
                    $p->cardiologist_report = $body;
                    $p->updated_at = $reported;
                } else {
                    $p->updated_at = $when;
                }
                $p->created_at = $when;
                $p->timestamps = false;
                $p->save();

                if ($status === 'requested' && $p->cardiologist_id) {
                    $note = Notification::create(['sender_id' => $st->id, 'receiver_id' => $p->cardiologist_id, 'title' => $st->name.' New ECG Report Uploaded']);
                    $note->created_at = $p->requested_time;
                    $note->updated_at = $p->requested_time;
                    $note->save();
                }
            }
        }
    }
}
