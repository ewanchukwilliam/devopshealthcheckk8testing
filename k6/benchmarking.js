  import http from 'k6/http';
  import { check, sleep } from 'k6';

  export const options = {
    stages: [
      { duration: '30s', target: 500 },  // Ramp to 200 users
      { duration: '2m', target: 500 },  // Ramp to 200 users
      { duration: '1m', target: 0 },    // Ramp down
    ],
  };

  export default function () {
    const res = http.get('http://localhost/health');

    check(res, {
      'status is 200': (r) => r.status === 200,
    });
	sleep(0.0001);  // 100ms think time = ~10 requests/second per user
  }

