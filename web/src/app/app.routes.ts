import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: 'auth',
    loadChildren: () => import('./features/auth/auth.routes').then(m => m.AUTH_ROUTES)
  },
  {
    path: '',
    loadComponent: () => import('./layout/shell/shell.component').then(m => m.ShellComponent),
    // canActivate: [authGuard] (Wird von Agent 02 hinzugefügt)
    children: [
      {
        path: 'dashboard',
        loadComponent: () => import('./features/time-tracking/components/dashboard/dashboard.component').then(m => m.DashboardComponent),
        title: 'Dashboard'
      },
      {
        path: 'reports',
        loadComponent: () => import('./features/reports/components/reports-overview/reports-overview.component').then(m => m.ReportsOverviewComponent),
        title: 'Berichte'
      },
      {
        path: 'reports/monthly',
        loadComponent: () => import('./features/reports/components/monthly-report/monthly-report.component').then(m => m.MonthlyReportComponent),
        title: 'Monatsbericht'
      },
      {
        path: 'reports/yearly',
        loadComponent: () => import('./features/reports/components/yearly-report/yearly-report.component').then(m => m.YearlyReportComponent),
        title: 'Jahresbericht'
      },
      {
        path: 'settings/profile',
        loadComponent: () => import('./features/settings/components/profile/profile.component').then(m => m.ProfileComponent),
        title: 'Profil'
      },
      {
        path: 'settings/app',
        loadComponent: () => import('./features/settings/components/app-settings/app-settings.component').then(m => m.AppSettingsComponent),
        title: 'Einstellungen'
      },
      {
        path: 'settings/profiles',
        loadComponent: () => import('./features/settings/components/profiles/profiles.component').then(m => m.ProfilesComponent),
        title: 'Arbeitgeber'
      },
      {
        path: 'settings/premium',
        loadComponent: () => import('./features/premium/components/paywall/paywall.component').then(m => m.PaywallComponent),
        title: 'Premium'
      },
      { path: '', redirectTo: 'dashboard', pathMatch: 'full' }
    ]
  },
  { path: '**', redirectTo: 'dashboard' }
];
