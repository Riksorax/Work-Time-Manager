// app.routes.ts

import { Routes } from '@angular/router';
import { authGuard } from './core/auth/auth.guard';
import { premiumGuard } from './core/security/premium.guard';

export const routes: Routes = [
  // ─── Auth (öffentlich) ──────────────────────────────────────────────────
  {
    path: 'auth',
    loadComponent: () => import('./features/auth/components/auth-layout/auth-layout.component')
      .then(m => m.AuthLayoutComponent),
    children: [
      {
        path: 'login',
        loadComponent: () => import('./features/auth/components/login/login.component')
          .then(m => m.LoginComponent),
      },
      {
        path: 'register',
        loadComponent: () => import('./features/auth/components/register/register.component')
          .then(m => m.RegisterComponent),
      },
      {
        path: 'forgot-password',
        loadComponent: () => import('./features/auth/components/forgot-password/forgot-password.component')
          .then(m => m.ForgotPasswordComponent),
      },
      { path: '', redirectTo: 'login', pathMatch: 'full' },
    ],
  },

  // ─── App (kein AuthGuard — App ist ohne Login nutzbar, Daten lokal gespeichert) ──
  {
    path: '',
    loadComponent: () => import('./layout/shell/shell.component')
      .then(m => m.ShellComponent),
    children: [
      // Dashboard
      {
        path: 'dashboard',
        loadComponent: () => import('./features/time-tracking/components/dashboard/dashboard.component')
          .then(m => m.DashboardComponent),
        title: 'Dashboard – Work-Time-Manager',
      },

      // Zeiterfassung
      {
        path: 'time-tracking',
        children: [
          {
            path: '',
            loadComponent: () => import('./features/time-tracking/components/session-list/session-list.component')
              .then(m => m.SessionListComponent),
            title: 'Zeiterfassung – Work-Time-Manager',
          },
          {
            path: ':id',
            loadComponent: () => import('./features/time-tracking/components/session-detail/session-detail.component')
              .then(m => m.SessionDetailComponent),
            title: 'Session bearbeiten – Work-Time-Manager',
          },
        ],
      },

      // Berichte (Basis frei, Detail Premium)
      {
        path: 'reports',
        children: [
          {
            path: '',
            loadComponent: () => import('./features/reports/components/reports-overview/reports-overview.component')
              .then(m => m.ReportsOverviewComponent),
            title: 'Berichte – Work-Time-Manager',
          },
          {
            path: 'monthly',
            loadComponent: () => import('./features/reports/components/monthly-report/monthly-report.component')
              .then(m => m.MonthlyReportComponent),
            canActivate: [premiumGuard],
            title: 'Monatsbericht – Work-Time-Manager',
          },
          {
            path: 'yearly',
            loadComponent: () => import('./features/reports/components/yearly-report/yearly-report.component')
              .then(m => m.YearlyReportComponent),
            canActivate: [premiumGuard],
            title: 'Jahresbericht – Work-Time-Manager',
          },
        ],
      },

      // Einstellungen
      {
        path: 'settings',
        children: [
          {
            path: '',
            redirectTo: 'profile',
            pathMatch: 'full',
          },
          {
            path: 'profile',
            loadComponent: () => import('./features/settings/components/profile/profile.component')
              .then(m => m.ProfileComponent),
            title: 'Profil – Work-Time-Manager',
          },
          {
            path: 'app',
            loadComponent: () => import('./features/settings/components/app-settings/app-settings.component')
              .then(m => m.AppSettingsComponent),
            title: 'App-Einstellungen – Work-Time-Manager',
          },
          {
            path: 'premium',
            loadComponent: () => import('./features/premium/components/paywall/paywall.component')
              .then(m => m.PaywallComponent),
            title: 'Premium – Work-Time-Manager',
          },
          {
            path: 'notifications',
            loadComponent: () => import('./features/notifications/components/notification-settings/notification-settings.component')
              .then(m => m.NotificationSettingsComponent),
            title: 'Benachrichtigungen – Work-Time-Manager',
          },
          // Premium: Multi-Profile (#138)
          {
            path: 'profiles',
            loadComponent: () => import('./features/settings/components/profiles/profiles.component')
              .then(m => m.ProfilesComponent),
            canActivate: [premiumGuard],
            title: 'Profile – Work-Time-Manager',
          },
        ],
      },

      { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
    ],
  },

  // Fallback
  { path: '**', redirectTo: '/dashboard' },
];
