# Push to GitLab - Command Reference

## ✅ Pre-Push Verification

Run these commands to verify everything is secure:

```bash
cd /Users/josephvore/CODE/vps-setup

# 1. Check git status
git status

# 2. Verify no tracked secrets
git ls-files | grep -E '\.(env|sql|dump|key|pem|crt)$'
# Should return nothing

# 3. Verify .gitignore works
git check-ignore .env .env.local
# Should show: .env and .env.local are ignored
```

---

## 🚀 Push to GitLab

### Option A: If you already have a GitLab repository set up

```bash
cd /Users/josephvore/CODE/vps-setup

# Verify remote is configured
git remote -v
# Should show: origin    git@gitlab.your-domain.com:your-org/vps-setup.git

# Push to main branch
git push -u origin main
```

### Option B: If you need to create the remote

```bash
cd /Users/josephvore/CODE/vps-setup

# Add GitLab remote (replace YOUR-DOMAIN and YOUR-ORG)
git remote add origin git@gitlab.your-domain.com:your-org/vps-setup.git

# Verify it was added
git remote -v

# Push to main branch
git push -u origin main
```

### Option C: If you need to update the remote URL

```bash
cd /Users/josephvore/CODE/vps-setup

# Update existing remote
git remote set-url origin git@gitlab.your-domain.com:your-org/vps-setup.git

# Verify
git remote -v

# Push to main branch
git push -u origin main
```

---

## 📋 Complete Push Workflow

Here's the complete step-by-step workflow:

```bash
cd /Users/josephvore/CODE/vps-setup

# 1. Verify no sensitive files
echo "Checking for sensitive files..."
git ls-files | grep -E '\.(env|sql|dump|key|pem|crt)$' || echo "✅ Clean"

# 2. Check git status
echo "Checking git status..."
git status --short | head -20

# 3. Add all files
echo "Adding all files to staging..."
git add .

# 4. Verify what will be committed
echo "Files to be committed:"
git diff --cached --name-only

# 5. Create commit
echo "Creating commit..."
git commit -m "feat: production-ready vps-setup repository

- Comprehensive security audit completed
- Dynamic SSH configuration throughout  
- Modular deployment scripts for any environment
- Complete documentation and guides
- No hardcoded credentials or sensitive data
- Ready for private GitLab repository

Security:
- No hardcoded passwords or API keys
- Environment-driven configuration
- Comprehensive .gitignore
- SSH key-based authentication
- Audit trails and logging

Documentation:
- SECURITY-AUDIT-FINAL.md - Security review
- GITLAB-DEPLOYMENT-GUIDE.md - Deployment instructions
- PRE-COMMIT-CHECKLIST.md - Verification steps
- GITLAB-READY.md - Summary
- Service guides and examples

Team Ready:
- Easy to understand and maintain
- Clear setup instructions
- Multiple deployment options
- Troubleshooting guides included"

# 6. Verify commit
echo "Verifying commit..."
git log --oneline -1

# 7. Push to GitLab
echo "Pushing to GitLab..."
git push -u origin main

# 8. Verify push was successful
echo "Verification complete!"
git log --oneline -1
git remote -v
```

---

## 🔒 Important Before Pushing

### Ensure GitLab Repository is Private

1. Go to: `https://gitlab.your-domain.com/your-org/vps-setup`
2. Click **Settings** → **General**
3. Under "Visibility", select **Private**
4. Click **Save changes**

### Ensure SSH Access is Configured

```bash
# Test SSH to GitLab
ssh git@gitlab.your-domain.com

# If it fails, you may need HTTPS instead:
git remote set-url origin https://gitlab.your-domain.com/your-org/vps-setup.git
git push -u origin main
```

---

## ✅ After Push - Verification

Once you've pushed, verify on GitLab:

```bash
# 1. Visit GitLab repository
https://gitlab.your-domain.com/your-org/vps-setup

# 2. Check visibility is Private ✅
# Settings → General → Visibility: Private

# 3. Verify files are present ✅
# Should see README.md and all .md files
# Should NOT see .env files

# 4. Check recent commits ✅
# Your commit should be visible in Commits tab

# 5. Add team members ✅
# Settings → Members → Invite members

# 6. Test team access ✅
# Team members should be able to clone:
# git clone git@gitlab.your-domain.com:your-org/vps-setup.git
```

---

## 🆘 Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connection
ssh -v git@gitlab.your-domain.com

# If fails, try HTTPS instead:
git remote set-url origin https://gitlab.your-domain.com/your-org/vps-setup.git
git push -u origin main

# Or generate SSH key if needed:
ssh-keygen -t ed25519 -C "your-email@example.com"
# Then add public key to GitLab: Settings → SSH Keys
```

### Remote Already Exists

```bash
# If you get "fatal: remote origin already exists"
git remote remove origin
git remote add origin git@gitlab.your-domain.com:your-org/vps-setup.git
git push -u origin main
```

### Branch Protection

```bash
# If main branch is protected, create different branch:
git checkout -b initial-setup
git push -u origin initial-setup
# Then create merge request on GitLab to merge into main
```

---

## 📊 What Gets Pushed

### Files That Will Be Committed
✅ All documentation (.md files)
✅ All scripts (.sh files)
✅ Configuration templates (.conf, .nginx, .example files)
✅ .gitignore (prevents sensitive files)

### Files That Will NOT Be Committed
❌ .env files (excluded by .gitignore)
❌ *.sql, *.dump files (excluded by .gitignore)
❌ *.key, *.pem, *.crt files (excluded by .gitignore)
❌ Node modules, build artifacts (excluded)
❌ System files (.DS_Store, etc.)

---

## 🎯 Quick Command Summary

```bash
# Navigate to repository
cd /Users/josephvore/CODE/vps-setup

# Add all files
git add .

# Commit changes
git commit -m "feat: production-ready vps-setup repository"

# Push to GitLab
git push -u origin main

# Done! ✅
```

---

## 📞 After Pushing

### Share with Team

```bash
# Team members can now clone:
git clone git@gitlab.your-domain.com:your-org/vps-setup.git
cd vps-setup

# They can follow setup instructions:
cat QUICK-START.md

# Or detailed deployment guide:
cat GITLAB-DEPLOYMENT-GUIDE.md
```

### Ready for Deployments

Team members can now deploy to any VPS:

```bash
# Create their local .env (not committed)
cat > .env << EOF
SSH_HOST="their-vps.com"
POSTGRES_PASSWORD="secure-password"
TS_AUTHKEY="tskey_..."
EOF

# Deploy!
./scripts/deploy.sh web
./scripts/deploy.sh database
./scripts/deploy.sh production
```

---

## ✨ Success!

Once pushed, your team has:

✅ **Secure Repository** - No hardcoded secrets
✅ **Complete Documentation** - Everything explained
✅ **Production-Ready Scripts** - Deploy in minutes
✅ **Team Collaboration** - Everyone can contribute
✅ **Best Practices** - Industry-standard approach

**Your vps-setup repository is live on GitLab!** 🎉

