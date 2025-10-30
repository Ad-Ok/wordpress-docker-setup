#!/bin/bash
# 🔑 Generate WordPress Authentication Keys and Salts
# Generates random keys for WordPress security

# Output format for .env file (without comments)
echo "AUTH_KEY='$(openssl rand -base64 48)'"
echo "SECURE_AUTH_KEY='$(openssl rand -base64 48)'"
echo "LOGGED_IN_KEY='$(openssl rand -base64 48)'"
echo "NONCE_KEY='$(openssl rand -base64 48)'"
echo "AUTH_SALT='$(openssl rand -base64 48)'"
echo "SECURE_AUTH_SALT='$(openssl rand -base64 48)'"
echo "LOGGED_IN_SALT='$(openssl rand -base64 48)'"
echo "NONCE_SALT='$(openssl rand -base64 48)'"