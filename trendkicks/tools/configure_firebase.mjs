// Imports only PUBLIC Android Firebase configuration, never a service account.
import { readFile, writeFile } from 'node:fs/promises';
const source = process.argv[2] ?? 'android/app/google-services.json';
const config = JSON.parse(await readFile(source, 'utf8'));
if (config.private_key || config.type === 'service_account') {
  throw new Error('Use Android google-services.json, not a server service-account file.');
}
const app = config.client?.find(c => c.client_info?.android_client_info?.package_name === 'com.example.trendkicks');
const values = { FCM_API_KEY: app?.api_key?.[0]?.current_key,
  FCM_APP_ID: app?.client_info?.mobilesdk_app_id,
  FCM_SENDER_ID: config.project_info?.project_number,
  FCM_PROJECT_ID: config.project_info?.project_id };
if (Object.values(values).some(value => typeof value !== 'string' || !value)) {
  throw new Error('Android Firebase configuration must include com.example.trendkicks and its public API/app/project values.');
}
const local = new URL('../config/local.json', import.meta.url);
const previous = JSON.parse(await readFile(local, 'utf8'));
await writeFile(local, JSON.stringify({...previous, ...values}, null, 2) + '\n');
console.log('Imported four public Firebase values. Existing Supabase configuration is preserved. Rebuild the APK.');
