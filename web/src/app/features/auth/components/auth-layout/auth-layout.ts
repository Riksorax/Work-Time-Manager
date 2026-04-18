import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet } from '@angular/router';
import { MatCardModule } from '@angular/material/card';

@Component({
  selector: 'app-auth-layout',
  standalone: true,
  imports: [CommonModule, RouterOutlet, MatCardModule],
  template: `
    <div class="auth-wrapper">
      <mat-card class="auth-card">
        <div class="auth-header">
          <img src="assets/icon/WorkTimeManagerLogo.png" alt="Logo" class="logo">
          <h1>Work-Time-Manager</h1>
        </div>
        <mat-card-content>
          <router-outlet></router-outlet>
        </mat-card-content>
      </mat-card>
    </div>
  `,
  styles: `
    .auth-wrapper {
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      background-color: #f5f5f5;
      padding: 1rem;
    }
    .auth-card {
      width: 100%;
      max-width: 420px;
      padding: 1rem;
    }
    .auth-header {
      text-align: center;
      margin-bottom: 2rem;
    }
    .logo {
      width: 80px;
      height: 80px;
      margin-bottom: 1rem;
    }
    h1 {
      margin: 0;
      font-size: 1.5rem;
      color: #3f51b5;
    }
    @media (max-width: 480px) {
      .auth-wrapper { padding: 0; }
      .auth-card { height: 100vh; max-width: none; border-radius: 0; }
    }
  `
})
export class AuthLayoutComponent {}
