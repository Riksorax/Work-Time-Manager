import { Routes } from '@angular/router';
import { authGuard } from './core/auth/auth.guard';

export const routes: Routes = [
  {
    path: 'auth',
    loadChildren: () => import('./features/auth/auth.routes').then(m => m.AUTH_ROUTES)
  },
  {
    path: '',
    loadComponent: () => import('./layout/shell/shell').then(m => m.ShellComponent),
    canActivate: [authGuard],
    children: [
      {
        path: 'dashboard',
        loadComponent: () => import('./features/time-tracking/components/dashboard/dashboard').then(m => m.DashboardComponent),
        title: 'Dashboard'
      },
      {
        path: 'reports',
        loadComponent: () => import('./features/reports/components/reports-overview/reports-overview').then(m => m.ReportsOverviewComponent),
        title: 'Berichte'
      },
      {
        path: 'reports/monthly',
        loadComponent: () => import('./features/reports/components/monthly-report/monthly-report').then(m => m.MonthlyReportComponent),
        title: 'Monatsbericht'
      },
      {
        path: 'settings/profile',
        loadComponent: () => import('./features/settings/components/profile/profile').then(m => m.ProfileComponent),
        title: 'Profil'
      },
      {
        path: 'settings/notifications',
        loadComponent: () => import('./features/notifications/components/notification-settings/notification-settings').then(m => m.NotificationSettingsComponent),
        title: 'Benachrichtigungen'
      },
      {
        path: 'settings/app',
        loadComponent: () => import('./features/settings/components/app-settings/app-settings').then(m => m.AppSettingsComponent),
        title: 'Einstellungen'
      },
      {
        path: 'settings/premium',
        loadComponent: () => import('./features/premium/components/paywall/paywall').then(m => m.PaywallComponent),
        title: 'Premium'
      },
      { path: '', redirectTo: 'dashboard', pathMatch: 'full' }
    ]
  },
  { path: '**', redirectTo: 'dashboard' }
];
