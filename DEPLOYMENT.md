# Deployment Guide

## Cloudflare Tunnel Deployment

This guide covers deploying the Refractometry IoT MVP through a Cloudflare tunnel.

### Prerequisites

- Cloudflare account with tunnel configured
- Domain name configured in Cloudflare
- Docker and Docker Compose installed
- Environment variables configured

### Step 1: Environment Configuration

Create a `.env` file in the project root:

```bash
# Database
POSTGRES_USER=refract
POSTGRES_PASSWORD=<strong-random-password>
POSTGRES_DB=refract_iot

# Backend API
DATABASE_URL=postgresql://refract:<password>@postgres:5432/refract_iot
API_HOST=0.0.0.0
API_PORT=8000

# CORS - Add your Cloudflare domain
CORS_ORIGINS=https://your-domain.com,https://app.your-domain.com

# API Key Authentication (enable for production)
API_KEY_REQUIRED=true
API_KEY=<generate-strong-random-key>

# Environment
ENVIRONMENT=production
```

### Step 2: Build Frontend with API URL

The frontend needs to know the API URL at build time. Set the `API_BASE_URL` environment variable:

```bash
cd web
export API_BASE_URL=https://api.your-domain.com
flutter build web --dart-define=API_BASE_URL=$API_BASE_URL
```

Or use the default (localhost) for development:

```bash
cd web
flutter build web
```

### Step 3: Configure Cloudflare Tunnel

Create a `cloudflared` configuration file (`config.yml`):

```yaml
tunnel: <your-tunnel-id>
credentials-file: /path/to/credentials.json

ingress:
  # Frontend web app
  - hostname: your-domain.com
    service: http://localhost:8080
    originRequest:
      httpHostHeader: your-domain.com
  
  # Backend API
  - hostname: api.your-domain.com
    service: http://localhost:9000
    originRequest:
      httpHostHeader: api.your-domain.com
  
  # Catch-all
  - service: http_status:404
```

### Step 4: Start Services

1. **Start backend services**:
   ```bash
   docker compose up -d
   ```

2. **Serve frontend** (choose one):
   
   **Option A: Flutter dev server** (development):
   ```bash
   cd web
   flutter run -d chrome --web-port=8080
   ```
   
   **Option B: Static file server** (production):
   ```bash
   cd web/build/web
   python3 -m http.server 8080
   # Or use nginx, Caddy, etc.
   ```

3. **Start Cloudflare tunnel**:
   ```bash
   cloudflared tunnel --config config.yml run
   ```

### Step 5: Verify Deployment

1. **Check backend health**:
   ```bash
   curl https://api.your-domain.com/health
   ```

2. **Check frontend**:
   Open `https://your-domain.com` in browser

3. **Verify CORS**:
   Frontend should be able to call backend API without CORS errors

### Security Considerations

1. **Enable API Key Authentication**:
   - Set `API_KEY_REQUIRED=true` in `.env`
   - Generate a strong random API key
   - Configure devices to use the API key

2. **HTTPS Only**:
   - Cloudflare tunnel provides HTTPS automatically
   - Ensure backend accepts HTTPS connections

3. **Database Security**:
   - Use strong database passwords
   - Don't expose database port externally
   - Consider using managed database service (RDS, etc.)

4. **Environment Variables**:
   - Never commit `.env` files to Git
   - Use secrets management in production
   - Rotate API keys regularly

### Troubleshooting

**CORS Errors**:
- Verify `CORS_ORIGINS` includes your frontend domain
- Check browser console for specific CORS error
- Ensure protocol matches (http vs https)

**API Connection Failed**:
- Verify Cloudflare tunnel is running
- Check backend logs: `docker compose logs backend`
- Verify API URL in frontend matches backend domain

**Database Connection Issues**:
- Check database is running: `docker compose ps`
- Verify `DATABASE_URL` in `.env` matches docker-compose.yml
- Check database logs: `docker compose logs postgres`

### Production Checklist

- [ ] Strong database password set
- [ ] API key authentication enabled
- [ ] CORS origins configured correctly
- [ ] HTTPS enabled (via Cloudflare)
- [ ] Environment variables secured
- [ ] Database backups configured
- [ ] Monitoring and logging set up
- [ ] Error tracking configured (optional)
- [ ] Rate limiting enabled (optional)
