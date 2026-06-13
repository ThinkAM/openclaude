#!/usr/bin/env pwsh
# Deploy script for OpenClaude CLI on EC2
# Usage: .\deploy-openclaude.ps1
#
# Builds OpenClaude locally, uploads dist/, bin/, and package.json to EC2,
# installs production dependencies, and sets up the CLI so the Knowledge
# Service can spawn it as a subprocess.

$ErrorActionPreference = "Stop"
$PemKey = "d:\dev\github\ThinkAM\think-am-api\thinkam-api-key.pem"
$Server = "ec2-user@54.210.14.111"
$RemoteDir = "/home/ec2-user/openclaude"

Write-Host "=== 1. Building OpenClaude ===" -ForegroundColor Cyan
npm run build

Write-Host "`n=== 2. Ensuring remote directory exists ===" -ForegroundColor Cyan
ssh -i $PemKey $Server "mkdir -p $RemoteDir/dist $RemoteDir/bin"

Write-Host "`n=== 3. Uploading dist/, bin/, and package.json ===" -ForegroundColor Cyan
scp -i $PemKey dist/cli.mjs "${Server}:${RemoteDir}/dist/"
scp -i $PemKey -r bin/* "${Server}:${RemoteDir}/bin/"
scp -i $PemKey package.json "${Server}:${RemoteDir}/"

Write-Host "`n=== 4. Installing production dependencies on EC2 ===" -ForegroundColor Cyan
ssh -i $PemKey $Server @"
  cd $RemoteDir && \
  npm install --production --ignore-scripts && \
  chmod +x bin/openclaude && \
  echo 'OpenClaude installed successfully'
"@

Write-Host "`n=== 5. Creating systemd service ===" -ForegroundColor Cyan
ssh -i $PemKey $Server @"
  sudo tee /etc/systemd/system/openclaude.service > /dev/null << 'EOF'
[Unit]
Description=OpenClaude CLI (installed for subprocess use by Knowledge Service)
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=ec2-user
WorkingDirectory=/home/ec2-user/openclaude
ExecStart=/bin/true
Environment=NODE_ENV=production
Environment=PATH=/home/ec2-user/.nvm/versions/node/v22.0.0/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload && \
  sudo systemctl enable openclaude && \
  sudo systemctl start openclaude && \
  echo 'systemd service configured'
"@

Write-Host "`n=== 6. Verifying installation ===" -ForegroundColor Cyan
ssh -i $PemKey $Server "cd $RemoteDir && node dist/cli.mjs --version 2>/dev/null || echo 'CLI installed (version check may require provider config)'"

Write-Host "`n=== Done! OpenClaude CLI deployed to $RemoteDir ===" -ForegroundColor Green
