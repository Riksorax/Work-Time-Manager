import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatListModule } from '@angular/material/list';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatChipsModule } from '@angular/material/chips';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-sidebar',
  standalone: true,
  imports: [
    CommonModule, 
    MatListModule, 
    MatIconModule, 
    MatDividerModule, 
    MatChipsModule,
    RouterLink, 
    RouterLinkActive,
    TranslateModule
  ],
  template: `
    <div class="sidebar-container">
      <mat-nav-list>
        <a mat-list-item routerLink="/dashboard" routerLinkActive="active-link">
          <mat-icon matListItemIcon>dashboard</mat-icon>
          <span matListItemTitle>{{ 'nav.dashboard' | translate }}</span>
        </a>
        <a mat-list-item routerLink="/reports" routerLinkActive="active-link">
          <mat-icon matListItemIcon>bar_chart</mat-icon>
          <span matListItemTitle>{{ 'nav.reports' | translate }}</span>
        </a>
        <a mat-list-item routerLink="/settings/profile" routerLinkActive="active-link">
          <mat-icon matListItemIcon>person</mat-icon>
          <span matListItemTitle>{{ 'nav.profile' | translate }}</span>
        </a>
        <a mat-list-item routerLink="/settings/app" routerLinkActive="active-link">
          <mat-icon matListItemIcon>settings</mat-icon>
          <span matListItemTitle>{{ 'nav.settings' | translate }}</span>
        </a>
      </mat-nav-list>

      <div class="spacer"></div>

      <mat-divider></mat-divider>
      
      <div class="user-footer">
        <div class="user-info">
          <span class="user-name">User Name</span>
          @if (isPremium) {
            <mat-chip-set>
              <mat-chip class="premium-chip">PRO</mat-chip>
            </mat-chip-set>
          }
        </div>
        <button mat-icon-button (click)="logout.emit()" title="Logout">
          <mat-icon>logout</mat-icon>
        </button>
      </div>
    </div>
  `,
  styles: `
    .sidebar-container {
      display: flex;
      flex-direction: column;
      height: 100%;
    }
    .spacer { flex: 1; }
    .active-link {
      background: rgba(63, 81, 181, 0.1);
      color: #3f51b5;
    }
    .user-footer {
      padding: 1rem;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .user-info {
      display: flex;
      flex-direction: column;
    }
    .user-name {
      font-weight: 500;
      font-size: 0.9rem;
    }
    .premium-chip {
      background-color: #ffc107 !important;
      font-size: 10px;
      min-height: 20px;
      padding: 0 8px;
    }
  `
})
export class SidebarComponent {
  @Input() isPremium: boolean = false;
  @Output() logout = new EventEmitter<void>();
}
