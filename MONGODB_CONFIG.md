# MongoDB Environment Configuration

## Default Configuration
This app uses these default settings:

```
MongoDB URL:    mongodb://localhost:27017
Database Name:  dyslexia_content
Backend URL:    http://127.0.0.1:5000
Backend Port:   5000
```

## For Custom MongoDB Instance

### Option 1: Local MongoDB (Default)
No configuration needed. MongoDB runs on your machine.

```bash
# Windows
net start MongoDB

# macOS
brew services start mongodb-community

# Linux
sudo systemctl start mongodb
```

### Option 2: Remote MongoDB (Atlas or other service)

Create `.env` file in `content-service/` directory:

```env
# MongoDB Atlas Example
MONGO_URL=mongodb+srv://username:password@cluster.mongodb.net/?retryWrites=true&w=majority
MONGO_DB=dyslexia_content

# MongoDB Enterprise/Standard Example
MONGO_URL=mongodb://your-host:27017
MONGO_DB=dyslexia_content
```

### Option 3: Docker MongoDB

Run MongoDB in Docker:

```bash
docker run -d \
  --name dyslexia-mongo \
  -p 27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=password \
  mongo:latest
```

Then use in `.env`:

```env
MONGO_URL=mongodb://admin:password@localhost:27017
MONGO_DB=dyslexia_content
```

### Option 4: Docker Compose

Create `docker-compose.yml`:

```yaml
version: '3.8'
services:
  mongodb:
    image: mongo:latest
    container_name: dyslexia-mongo
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: password
    volumes:
      - mongo_data:/data/db
  
  backend:
    build: ./content-service
    container_name: dyslexia-backend
    ports:
      - "5000:5000"
    environment:
      MONGO_URL: mongodb://admin:password@mongodb:27017
      MONGO_DB: dyslexia_content
    depends_on:
      - mongodb

volumes:
  mongo_data:
```

Start with: `docker-compose up`

## Flutter Configuration

If you need to connect to a different backend:

Edit `lib/services/content_service.dart`:

```dart
class ContentService {
  // Change this to your backend URL
  static const String baseUrl = 'http://192.168.1.100:5000/api';
  // or for remote: 'https://api.example.com/api'
  
  // ... rest of code
}
```

## Deployment Options

### Option 1: Local Development (Default)
```
MongoDB: localhost:27017
Backend: http://127.0.0.1:5000
App: Running on local device/emulator
```

### Option 2: Development with Remote Data
```
MongoDB: MongoDB Atlas (cloud)
Backend: Cloud server (Heroku, AWS, etc.)
App: Local device/emulator connecting to cloud
```

### Option 3: Production Deployment
```
MongoDB: MongoDB Atlas (production cluster)
Backend: Cloud server with SSL/TLS
App: Published to app stores
```

### Option 4: On-Premises Server
```
MongoDB: Self-hosted server
Backend: Self-hosted server
App: Can connect via VPN or public IP
```

## Connection String Examples

### Local MongoDB
```
mongodb://localhost:27017
```

### MongoDB Atlas (Cloud)
```
mongodb+srv://username:password@cluster0.mongodb.net/dyslexia_content?retryWrites=true&w=majority
```

### MongoDB Enterprise with Authentication
```
mongodb://username:password@server1:27017,server2:27017,server3:27017/?replicaSet=myReplicaSet&authSource=admin
```

### MongoDB with TLS
```
mongodb+srv://username:password@cluster.mongodb.net/database?tlsCAFile=/path/to/ca.pem
```

## Backend Port Configuration

If port 5000 is already in use:

```bash
# Run on different port
python -m uvicorn main:app --port 8000

# Update Flutter code
static const String baseUrl = 'http://127.0.0.1:8000/api';
```

## Environment Variables

### For Backend
```env
MONGO_URL=mongodb://localhost:27017
MONGO_DB=dyslexia_content
FLASK_ENV=development  # or production
```

### For Flutter
No environment variables needed - all config in code, or use:

```bash
# Build with different backend
flutter run -d chrome --dart-define=BACKEND_URL=http://example.com:5000
```

Then access in code:

```dart
static const String baseUrl = String.fromEnvironment('BACKEND_URL', 
  defaultValue: 'http://127.0.0.1:5000/api'
);
```

## Troubleshooting Connection Issues

### MongoDB Connection Refused
```
Error: [Errno 111] Connection refused
```
**Solution**: MongoDB not running
```bash
# Start MongoDB
mongod --dbpath /path/to/data
```

### Authentication Failed
```
Error: authentication failed
```
**Solution**: Check credentials in MONGO_URL
- Verify username and password are correct
- Check database name in connection string

### Network Unreachable
```
Error: No address associated with hostname
```
**Solution**: 
- Check hostname/IP is correct
- Check firewall allows MongoDB port (27017)
- Check server is running and accessible

### Port Already in Use
```
Error: Address already in use
```
**Solution**: Use different port or kill existing process
```bash
# Find process using port 5000
lsof -i :5000  # macOS/Linux
netstat -ano | findstr :5000  # Windows

# Kill process
kill -9 <PID>
```

## Performance Tips

### For Local Development
- Use local MongoDB
- Connection is very fast
- Good for testing

### For Cloud Deployment
- Use MongoDB Atlas (easy scaling)
- Use nearby region for lower latency
- Enable connection pooling
- Use index on frequently queried fields

### Monitor Connections
```bash
# Check MongoDB status
mongosh
> db.serverStatus()

# Check connected clients
> db.currentOp()
```

---

**Note**: Store sensitive credentials (passwords, connection strings) in environment variables or `.env` files, never commit to git.
