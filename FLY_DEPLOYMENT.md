# Fly.io Deployment with Persistent Storage

## Initial Setup

1. **Install flyctl** (if not already installed):
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```

2. **Login to Fly.io**:
   ```bash
   fly auth login
   ```

3. **Create the app** (update app name in fly.toml if needed):
   ```bash
   fly apps create recur-app
   ```

## Volume Management

4. **Create persistent volume**:
   ```bash
   # Create primary volume (required)
   fly volumes create recur_data --size 5gb --region ord
   
   # Optional: Create second volume for redundancy
   fly volumes create recur_data --size 5gb --region ord
   ```

5. **List volumes** (to verify):
   ```bash
   fly volumes list
   ```

## Deployment

6. **Deploy the application**:
   ```bash
   fly deploy
   ```

7. **Check deployment status**:
   ```bash
   fly status
   fly logs
   ```

## Post-Deployment

8. **Access your app**:
   ```bash
   fly open
   ```

9. **SSH into the machine** (for debugging):
   ```bash
   fly ssh console
   ```

10. **Monitor volume usage**:
    ```bash
    fly ssh console -C "df -h /data"
    ```

## Volume Management Commands

- **Create snapshot**: `fly volumes snapshots create <volume-id>`
- **List snapshots**: `fly volumes snapshots list`
- **Extend volume**: `fly volumes extend <volume-id> --size 10gb`
- **Delete volume**: `fly volumes delete <volume-id>`

## Database Location

The PocketBase database will be stored in `/data` on the persistent volume, ensuring data survives deployments and machine restarts.

## Troubleshooting

- If deployment fails, check `fly logs` for errors
- Ensure volume is created before deploying
- Database files are located at `/data/data.db` and `/data/logs.db`
- Volume auto-extends when 80% full (configured in fly.toml)