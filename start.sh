#!/bin/bash

echo "🚀 Starting Observability Stack with Tracing..."

# Check if the network exists, create if it doesn't
if ! docker network ls | grep -q "observability-stack"; then
    echo "📡 Creating observability-stack network..."
    docker network create observability-stack
fi

# Start the stack
echo "🔧 Starting services..."
docker-compose -f docker-compose.dev.yaml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check if services are running
echo "🔍 Checking service status..."
docker-compose -f docker-compose.dev.yaml ps

echo ""
echo "✅ Observability Stack is running!"
echo ""
echo "📊 Access your services:"
echo "   Grafana:     http://localhost:3000 (admin/admin)"
echo "   Jaeger UI:   http://localhost:16686"
echo "   Loki:        http://localhost:3100"
echo ""
echo "🔍 To add your own services with tracing:"
echo "   - Add them to docker-compose.dev.yaml"
echo "   - Use the observability-stack network"
echo "   - Instrument with OpenTelemetry and Jaeger exporter"
echo ""
echo "🛑 To stop the stack:"
echo "   docker-compose -f docker-compose.dev.yaml down" 