module.exports = ({ env }) => ({
  auth: {
    secret: env('ADMIN_JWT_SECRET','vLlVIDMWv9jq4ZuRmiV7Yg=='),
  },
  apiToken: {
    salt: env('API_TOKEN_SALT','AFD+bzxkxtBjdR79bduoVw=='),
  },
  transfer: {
    token: {
      salt: env('TRANSFER_TOKEN_SALT','K9hfMFAQxLrZfm6dwjL/MQ=='),
    },
  },
  flags: {
    nps: env.bool('FLAG_NPS', true),
    promoteEE: env.bool('FLAG_PROMOTE_EE', true),
  },
});
