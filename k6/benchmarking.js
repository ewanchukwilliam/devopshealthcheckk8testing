  import http from 'k6/http';
  import { check } from 'k6';

  export const options = {
    stages: [
      { duration: '2m', target: 200 },  // Ramp to 200 users
      { duration: '1m', target: 0 },    // Ramp down
    ],
  };

  export default function () {
    const res = http.get('http://localhost/health');

    check(res, {
      'status is 200': (r) => r.status === 200,
    });
  }

