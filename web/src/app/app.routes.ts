import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () => import('./layout/main-shell/main-shell').then(m => m.MainShellComponent),
    children: [
      {
        path: 'dashboard',
        title: 'Dashboard – Work Time Manager',
        loadComponent: () => import('./features/dashboard/dashboard').then(m => m.DashboardComponent)
      },
      {
        path: 'reports',
        title: 'Berichte – Work Time Manager',
        loadComponent: () => import('./features/reports/reports').then(m => m.ReportsComponent)
      },
      {
        path: 'settings',
        title: 'Einstellungen – Work Time Manager',
        loadComponent: () => import('./features/settings/settings').then(m => m.SettingsComponent)
      },
      { path: '', redirectTo: 'dashboard', pathMatch: 'full' }
    ]
  },
  {
    path: 'auth',
    children: [
      {
        path: 'login',
        title: 'Anmelden – Work Time Manager',
        loadComponent: () => import('./core/auth/login').then(m => m.LoginComponent)
      }
    ]
  }
];
