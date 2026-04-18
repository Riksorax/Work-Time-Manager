import { Routes } from '@angular/router';
import { AuthLayoutComponent } from './components/auth-layout/auth-layout';
import { LoginComponent } from './components/login/login';
import { RegisterComponent } from './components/register/register';
import { ForgotPasswordComponent } from './components/forgot-password/forgot-password';

export const AUTH_ROUTES: Routes = [
  {
    path: '',
    component: AuthLayoutComponent,
    children: [
      { path: 'login', component: LoginComponent, title: 'Anmelden' },
      { path: 'register', component: RegisterComponent, title: 'Registrieren' },
      { path: 'forgot-password', component: ForgotPasswordComponent, title: 'Passwort vergessen' },
      { path: '', redirectTo: 'login', pathMatch: 'full' }
    ]
  }
];
