// src/services/email.service.js

const nodemailer = require('nodemailer');
const path = require('path');
const fs = require('fs').promises;
const logger = require('../utils/logger');

class EmailService {
  constructor() {
    this.transporter = null;
    this.templateCache = new Map();
    this._init();
  }

  _init() {
    if (process.env.NODE_ENV === 'production' && process.env.SENDGRID_API_KEY) {
      // Will use SendGrid HTTP API, no transporter needed
      return;
    }

    // Otherwise fallback/development SMTP
    this.transporter = nodemailer.createTransport({
      host: process.env.EMAIL_HOST || 'smtp.mailtrap.io',
      port: parseInt(process.env.EMAIL_PORT) || 2525,
      secure: process.env.EMAIL_SECURE === 'true',
      connectionTimeout: 5000,
      greetingTimeout: 5000,
      socketTimeout: 5000,
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
      tls: {
        rejectUnauthorized: false,
      },
    });
  }

  // ── Load and cache HTML template ──────────────────────
  async _loadTemplate(templateName) {
    if (this.templateCache.has(templateName)) {
      return this.templateCache.get(templateName);
    }

    const templatePath = path.join(
      __dirname, '..', 'templates', `${templateName}.html`
    );

    const template = await fs.readFile(templatePath, 'utf-8');
    this.templateCache.set(templateName, template);
    return template;
  }

  // ── Replace template variables ─────────────────────────
  _renderTemplate(template, variables) {
    let rendered = template;
    for (const [key, value] of Object.entries(variables)) {
      const regex = new RegExp(`{{${key}}}`, 'g');
      rendered = rendered.replace(regex, value);
    }
    return rendered;
  }

  // ── Generic send ──────────────────────────────────────
  async send({ to, subject, html, text }) {
    try {
      if (process.env.NODE_ENV === 'production' && process.env.SENDGRID_API_KEY) {
        // Send via SendGrid HTTP API (Port 443) to bypass Render SMTP blocks!
        const axios = require('axios');
        await axios.post(
          'https://api.sendgrid.com/v3/mail/send',
          {
            personalizations: [
              {
                to: [{ email: to }],
              },
            ],
            from: {
              email: process.env.EMAIL_FROM || 'no-reply@instagram-clone.com',
              name: process.env.APP_NAME || 'Instagram Clone',
            },
            subject,
            content: [
              {
                type: 'text/html',
                value: html,
              },
            ],
          },
          {
            headers: {
              Authorization: `Bearer ${process.env.SENDGRID_API_KEY}`,
              'Content-Type': 'application/json',
            },
            timeout: 5000,
          }
        );
        logger.info(`Email sent via SendGrid HTTP API to ${to}`);
        return { success: true };
      }

      // Fallback / Development SMTP
      if (!this.transporter) {
        throw new Error('Nodemailer SMTP transporter not initialized');
      }

      const info = await this.transporter.sendMail({
        from: process.env.EMAIL_FROM,
        to,
        subject,
        html,
        text: text || html.replace(/<[^>]+>/g, ''), // Strip HTML for text
      });

      logger.info(`Email sent to ${to}: ${info.messageId}`);
      return { success: true, messageId: info.messageId };
    } catch (error) {
      logger.error(`Email failed to ${to}:`, error.message);
      throw new Error(`Failed to send email: ${error.message}`);
    }
  }

  // ── Send OTP email ────────────────────────────────────
  async sendOtpEmail({ to, otp, type, username }) {
    try {
      const template = await this._loadTemplate(
        type === 'password_reset' ? 'reset-password' : 'verify-email'
      );

      const subjects = {
        email_verify: `${otp} is your ${process.env.APP_NAME || 'Instagram Clone'} verification code`,
        password_reset: `${otp} is your ${process.env.APP_NAME || 'Instagram Clone'} password reset code`,
        login: `${otp} is your ${process.env.APP_NAME || 'Instagram Clone'} login code`,
      };

      const titles = {
        email_verify: 'Verify your email',
        password_reset: 'Reset your password',
        login: 'Login verification',
      };

      const html = this._renderTemplate(template, {
        APP_NAME: process.env.APP_NAME || 'Instagram Clone',
        USERNAME: username || to.split('@')[0],
        OTP: otp,
        OTP_EXPIRES_MINUTES: process.env.OTP_EXPIRES_MINUTES || 10,
        TITLE: titles[type] || 'Verification Code',
        YEAR: new Date().getFullYear(),
        // Split OTP into individual digits for styling
        OTP_DIGITS: otp.split('').map(d =>
          `<span class="otp-digit">${d}</span>`).join(''),
      });

      return this.send({
        to,
        subject: subjects[type] || `Your ${process.env.APP_NAME || 'Instagram Clone'} code: ${otp}`,
        html,
      });
    } catch (err) {
      logger.error('Failed to load email template, sending fallback plain email: ', err);
      // Fallback if template files do not load
      return this.send({
        to,
        subject: `Your OTP is ${otp}`,
        html: `<p>Your OTP code is <b>${otp}</b>. It will expire in ${process.env.OTP_EXPIRES_MINUTES || 10} minutes.</p>`,
      });
    }
  }

  // ── Send welcome email ────────────────────────────────
  async sendWelcomeEmail({ to, username }) {
    try {
      const template = await this._loadTemplate('welcome');
      const html = this._renderTemplate(template, {
        APP_NAME: process.env.APP_NAME || 'Instagram Clone',
        USERNAME: username,
        YEAR: new Date().getFullYear(),
      });

      return this.send({
        to,
        subject: `Welcome to ${process.env.APP_NAME || 'Instagram Clone'}! 🎉`,
        html,
      });
    } catch (err) {
      return this.send({
        to,
        subject: `Welcome to our App!`,
        html: `<p>Welcome, ${username}! Thanks for verifying your account.</p>`,
      });
    }
  }

  // ── Send password changed notification ─────────────────
  async sendPasswordChangedEmail({ to, username }) {
    const html = `
      <p>Hi ${username},</p>
      <p>Your password for <strong>${process.env.APP_NAME || 'Instagram Clone'}</strong> was just changed.</p>
      <p>If you did not do this, please secure your account immediately.</p>
    `;

    return this.send({
      to,
      subject: `Your password was changed`,
      html,
    });
  }

  // ── Verify connection ─────────────────────────────────
  async verify() {
    try {
      if (process.env.NODE_ENV === 'production' && process.env.SENDGRID_API_KEY) {
        logger.info('✅ Email service configured via SendGrid HTTP API');
        return true;
      }
      if (!this.transporter) {
        throw new Error('Nodemailer SMTP transporter not initialized');
      }
      await this.transporter.verify();
      logger.info('✅ Email service connected via SMTP');
      return true;
    } catch (error) {
      logger.error('Email service error:', error.message);
      return false;
    }
  }
}

module.exports = new EmailService();
