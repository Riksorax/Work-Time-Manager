import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet, Router } from '@angular/router';
import { MatSidenavModule } from '@angular/material/sidenav';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { SidebarComponent } from '../sidebar/sidebar';
import { Auth } from '@angular/fire/auth';

@Component({
  selector: 'app-shell',
  standalone: true,
  imports: [
    CommonModule, 
    RouterOutlet, 
    MatSidenavModule, 
    MatToolbarModule, 
    MatButtonModule, 
    MatIconModule,
    SidebarComponent
  ],
  template: `
    <mat-sidenav-container class="shell-container">
      <mat-sidenav #sidenav [mode]="isMobile() ? 'over' : 'side'" [opened]="!isMobile()">
        <app-sidebar [isPremium]="isPremium()" (logout)="onLogout()"></app-sidebar>
      </mat-sidenav>

      <mat-sidenav-content>
        <mat-toolbar color="primary">
          @if (isMobile()) {
            <button mat-icon-button (click)="sidenav.toggle()">
              <mat-icon>menu</mat-icon>
            </button>
          }
          <span>Work-Time-Manager</span>
          <span class="toolbar-spacer"></span>
          <!-- Live Timer Widget Placeholder -->
        </mat-toolbar>

        <main class="content">
          <router-outlet></router-outlet>
        </main>
      </mat-sidenav-content>
    </mat-sidenav-container>
  `,
  styles: `
    .shell-container {
      height: 100vh;
    }
    mat-sidenav {
      width: 250px;
    }
    .toolbar-spacer {
      flex: 1 1 auto;
    }
    .content {
      padding: 1rem;
    }
  `
})
export class ShellComponent {
  private auth = inject(Auth);
  private router = inject(Router);

  isMobile = signal(window.innerWidth < 960);
  isPremium = signal(false);

  constructor() {
    window.addEventListener('resize', () => {
      this.isMobile.set(window.innerWidth < 960);
    });
  }

  async onLogout() {
    await this.auth.signOut();
    this.router.navigate(['/auth/login']);
  }
}
