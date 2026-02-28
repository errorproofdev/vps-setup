module.exports = {
  apps: [
    /**
     * ===========================================================================
     * APP 1: DetoxNearMe (Port 3000 - localhost-only TCP)
     * ===========================================================================
     * Database: PostgreSQL (sql-steelgem:5432)
     * CMS: Strapi (internal only)
     * Runs as: appuser (non-root)
     */
    {
      name: "detoxnearme",
      script: "npm",
      args: "run start",
      cwd: "/var/www/apps/detoxnearme",
      
      // =========== PROCESS MANAGEMENT ===========
      instances: 1,                           // Fork mode (single instance)
      exec_mode: "fork",                      // Not cluster mode
      autorestart: true,                      // Auto-restart if crashes
      watch: false,                           // Don't watch files in production
      
      // =========== RESOURCE LIMITS ===========
      max_memory_restart: "1G",               // Restart if exceeds 1GB RAM
      max_restarts: 10,                       // Max 10 restarts
      min_uptime: "10s",                      // In 10s window
      
      // =========== ENV: Reads from .env.local (PORT, DATABASE_URL, etc) ===========
      // Don't override here - let .env.local take precedence
      
      // =========== LOGGING ===========
      log_date_format: "YYYY-MM-DD HH:mm:ss Z",
      out_file: "/var/log/pm2/detoxnearme-out.log",
      error_file: "/var/log/pm2/detoxnearme-error.log",
      merge_logs: true,
      
      // =========== GRACEFUL SHUTDOWN ===========
      kill_timeout: 5000,                     // 5s grace before SIGKILL
      listen_timeout: 3000,
      shutdown_with_message: true,
    },

    /**
     * ===========================================================================
     * APP 2: Edge Treatment (Port 3001 - localhost-only TCP)
     * ===========================================================================
     * CMS: Contentful
     * Runs as: appuser (non-root)
     */
    {
      name: "edge",
      script: "npm",
      args: "run start",
      cwd: "/var/www/apps/edge-nextjs",
      
      // =========== PROCESS MANAGEMENT ===========
      instances: 1,
      exec_mode: "fork",
      autorestart: true,
      watch: false,
      find . -name '._*' -delete
      
      // =========== RESOURCE LIMITS ===========
      max_memory_restart: "1G",
      max_restarts: 10,
      min_uptime: "10s",
      
      // =========== ENV: Reads from .env.local (PORT=3001, Contentful keys, etc) ===========
      // Don't override PORT here - let .env.local take precedence
      
      // =========== LOGGING ===========
      log_date_format: "YYYY-MM-DD HH:mm:ss Z",
      out_file: "/var/log/pm2/edge-treatment-out.log",
      error_file: "/var/log/pm2/edge-treatment-error.log",
      merge_logs: true,
      
      // =========== GRACEFUL SHUTDOWN ===========
      kill_timeout: 5000,
      listen_timeout: 3000,
      shutdown_with_message: true,
    },

    /**
     * ===========================================================================
     * APP 3: Forge Recovery (Port 3002 - localhost-only TCP)
     * ===========================================================================
     * CMS: Contentful
     * Runs as: appuser (non-root)
     */
    {
      name: "forge",
      script: "npm",
      args: "run start",
      cwd: "/var/www/apps/forge-nextjs",
      
      // =========== PROCESS MANAGEMENT ===========
      instances: 1,
      exec_mode: "fork",
      autorestart: true,
      watch: false,
      
      // =========== RESOURCE LIMITS ===========
      max_memory_restart: "1G",
      max_restarts: 10,
      min_uptime: "10s",
      
      // =========== ENV: Reads from .env.local (PORT=3002, Contentful keys, etc) ===========
      // Don't override PORT here - let .env.local take precedence
      
      // =========== LOGGING ===========
      log_date_format: "YYYY-MM-DD HH:mm:ss Z",
      out_file: "/var/log/pm2/forge-recovery-out.log",
      error_file: "/var/log/pm2/forge-recovery-error.log",
      merge_logs: true,
      
      // =========== GRACEFUL SHUTDOWN ===========
      kill_timeout: 5000,
      listen_timeout: 3000,
      shutdown_with_message: true,
    },
  ],

  /**
   * Global configuration for all apps
   */
  monitor_delay: 5000,
  error_file: "/var/log/pm2/pm2.error.log",
  out_file: "/var/log/pm2/pm2.out.log",
  log_file: "/var/log/pm2/pm2.log",
  
  env: {
    NODE_ENV: "production",
  },
};