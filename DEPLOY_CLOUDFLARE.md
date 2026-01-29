# Deploy RefractIQ via Cloudflare Tunnel

This guide covers deploying RefractIQ frontend and backend through Cloudflare tunnel at `refractometry.wiredgateway.com`.

## Prerequisites

1. Cloudflare account with tunnel configured
2. Domain `refractometry.wiredgateway.com` configured in Cloudflare
3. Cloudflare tunnel created and credentials file available
4. Docker and Docker Compose installed
5. Python 3.9+ (for serving frontend)

## Step 1: Configure Backend CORS

The backend needs to allow requests from the frontend domain.

### Option A: Environment Variable (Recommended)

Create or update `.env` file in project root:

```bash
# CORS Configuration
CORS_ORIGINS=https://refractometry.wiredgateway.com,https://api.refractometry.wiredgateway.com

# Database (if not already set)
DATABASE_URL=postgresql://refract:refract_dev@postgres:5432/refract_iot
API_HOST=0.0.0.0
API_PORT=8000

# API Key (optional, recommended for production)
API_KEY_REQUIRED=false
API_KEY=your-secret-api-key-here
```

Then restart backend:

```bash
docker compose restart backend
```

### Option B: Update docker-compose.yml

Add to backend service environment:

```yaml
environment:
  CORS_ORIGINS: https://refractometry.wiredgateway.com,https://api.refractometry.wiredgateway.com
```

## Step 2: Build Frontend with Production API URL

The frontend has been built with the production API URL:

```bash
cd web
flutter build web --dart-define=API_BASE_URL=https://api.refractometry.wiredgateway.com
```

Built files are in `web/build/web/`

## Step 3: Start Backend Services

```bash
docker compose up -d
```

Verify backend is running:

```bash
curl http://localhost:9000/health
```

## Step 4: Serve Frontend Locally

The frontend needs to be served on port 8080 for the Cloudflare tunnel.

### Option A: Python HTTP Server (Simple)

```bash
cd web/build/web
python3 -m http.server 8080
```

### Option B: Nginx (Production)

Create nginx config:

```nginx
server {
    listen 8080;
    server_name refractometry.wiredgateway.com;
    root /path/to/refract-iot-mvp/web/build/web;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

## Step 5: Configure Cloudflare Tunnel

### Create Tunnel Configuration

Edit `cloudflare-tunnel-config.yml`:

```yaml
tunnel: <your-tunnel-id>
credentials-file: /path/to/credentials.json

ingress:
  # Frontend web app
  - hostname: refractometry.wiredgateway.com
    service: http://localhost:8080
    originRequest:
      httpHostHeader: refractometry.wiredgateway.com
  
  # Backend API
  - hostname: api.refractometry.wiredgateway.com
    service: http://localhost:9000
    originRequest:
      httpHostHeader: api.refractometry.wiredgateway.com
  
  # Catch-all
  - service: http_status:404
```

### Start Cloudflare Tunnel

```bash
cloudflared tunnel --config cloudflare-tunnel-config.yml run
```

Or run as a service (systemd):

```bash
sudo systemctl start cloudflared
```

## Step 6: Verify Deployment

1. **Check Frontend**: https://refractometry.wiredgateway.com
   - Should load the RefractIQ dashboard
   - Check browser console for errors

2. **Check Backend API**: https://api.refractometry.wiredgateway.com/health
   ```bash
   curl https://api.refractometry.wiredgateway.com/health
   ```

3. **Check API Docs**: https://api.refractometry.wiredgateway.com/docs

4. **Test CORS**: Open browser console on frontend, verify no CORS errors

## Troubleshooting

### CORS Errors

If you see CORS errors in browser console:

1. Verify `CORS_ORIGINS` includes `https://refractometry.wiredgateway.com`
2. Check backend logs: `docker compose logs backend`
3. Restart backend: `docker compose restart backend`

### Frontend Not Loading

1. Verify frontend server is running on port 8080
2. Check Cloudflare tunnel logs
3. Verify tunnel configuration has correct hostname

### API Not Accessible

1. Verify backend is running: `docker compose ps`
2. Check backend logs: `docker compose logs backend`
3. Test locally: `curl http://localhost:9000/health`
4. Verify tunnel configuration for `api.refractometry.wiredgateway.com`

### 404 Errors

1. Verify frontend build completed successfully
2. Check that `index.html` exists in `web/build/web/`
3. Ensure HTTP server is serving from correct directory

## Production Checklist

- [ ] Backend CORS configured for production domain
- [ ] Frontend built with production API URL
- [ ] API key authentication enabled (if desired)
- [ ] HTTPS enabled (Cloudflare provides this)
- [ ] Database credentials secured
- [ ] Cloudflare tunnel running as service
- [ ] Monitoring/logging configured
- [ ] Backup strategy in place

## Running as Services

### Systemd Service for Frontend

Create `/etc/systemd/system/refractiq-frontend.service`:

```ini
[Unit]
Description=RefractIQ Frontend Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/path/to/refract-iot-mvp/web/build/web
ExecStart=/usr/bin/python3 -m http.server 8080
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable refractiq-frontend
sudo systemctl start refractiq-frontend
```

### Systemd Service for Backend

Docker Compose already manages the backend. To ensure it starts on boot:

```bash
sudo systemctl enable docker
```

## Security Notes

1. **API Keys**: Enable API key authentication for production
2. **Database**: Use strong passwords, don't expose database port
3. **HTTPS**: Cloudflare tunnel provides HTTPS automatically
4. **CORS**: Only allow necessary origins
5. **Rate Limiting**: Consider adding rate limiting for production

## Next Steps

- Set up monitoring and alerting
- Configure database backups
- Set up CI/CD pipeline
- Add error tracking (Sentry, etc.)
- Configure log aggregation
