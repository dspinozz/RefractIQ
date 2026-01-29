# DNS Setup for RefractIQ

## Required DNS Records

You need to create **2 CNAME records** in your Cloudflare dashboard for the `wiredgateway.com` domain:

### 1. Frontend Dashboard

- **Type**: CNAME
- **Name**: `refractometry`
- **Target**: `0ff54825-ee15-41d0-a71d-19e893903d9b.cfargotunnel.com`
- **Proxy status**: ✅ **Proxied** (orange cloud)
- **TTL**: Auto

This will make `refractometry.wiredgateway.com` point to your Cloudflare tunnel.

### 2. Backend API

- **Type**: CNAME
- **Name**: `api.refractometry` (or `api` if using subdomain)
- **Target**: `0ff54825-ee15-41d0-a71d-19e893903d9b.cfargotunnel.com`
- **Proxy status**: ✅ **Proxied** (orange cloud)
- **TTL**: Auto

This will make `api.refractometry.wiredgateway.com` point to your Cloudflare tunnel.

## Steps in Cloudflare Dashboard

1. Go to Cloudflare Dashboard → Select `wiredgateway.com` domain
2. Click **DNS** → **Records**
3. Click **Add record**
4. For each record:
   - Type: CNAME
   - Name: `refractometry` (or `api.refractometry`)
   - Target: `0ff54825-ee15-41d0-a71d-19e893903d9b.cfargotunnel.com`
   - Proxy: ✅ Proxied (orange cloud)
   - Click **Save**

## Verification

After creating the DNS records (may take 1-2 minutes to propagate):

```bash
# Check DNS resolution
dig +short refractometry.wiredgateway.com
# Should return: 100.x.x.x (Cloudflare IP)

# Test frontend
curl https://refractometry.wiredgateway.com

# Test backend
curl https://api.refractometry.wiredgateway.com/health
```

## Tunnel Status

The tunnel is configured and running. Check status:

```bash
ps aux | grep cloudflared | grep api-config
```

View logs:

```bash
tail -f /tmp/cloudflared-api.log
```

## Troubleshooting

### DNS Not Resolving

- Wait 1-2 minutes after creating DNS records
- Verify records in Cloudflare dashboard
- Check that Proxy is enabled (orange cloud)
- Verify target is correct: `0ff54825-ee15-41d0-a71d-19e893903d9b.cfargotunnel.com`

### 502 Bad Gateway

- Check that local services are running:
  - Frontend: `curl http://localhost:8080`
  - Backend: `curl http://localhost:9000/health`
- Check tunnel logs: `tail -f /tmp/cloudflared-api.log`
- Verify tunnel is running: `ps aux | grep cloudflared`

### CORS Errors

- Verify backend CORS includes `https://refractometry.wiredgateway.com`
- Check `.env` file has correct `CORS_ORIGINS`
- Restart backend: `docker compose restart backend`
