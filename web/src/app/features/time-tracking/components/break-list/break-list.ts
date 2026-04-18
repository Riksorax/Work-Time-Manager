import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatListModule } from '@angular/material/list';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { Break } from '../../../../shared/models';

@Component({
  selector: 'app-break-list',
  standalone: true,
  imports: [CommonModule, MatListModule, MatIconModule, MatButtonModule],
  template: `
    @if (breaks.length === 0) {
      <p class="empty-msg">Keine Pausen für heute erfasst.</p>
    } @else {
      <mat-list>
        @for (b of breaks; track b.id) {
          <mat-list-item>
            <mat-icon matListItemIcon>coffee</mat-icon>
            <div matListItemTitle>{{ b.name }}</div>
            <div matListItemLine>
              {{ b.start | date:'HH:mm' }} - 
              {{ b.end ? (b.end | date:'HH:mm') : 'läuft...' }}
            </div>
            <button mat-icon-button matListItemMeta color="warn" (click)="delete.emit(b.id)">
              <mat-icon>delete</mat-icon>
            </button>
          </mat-list-item>
        }
      </mat-list>
    }
  `,
  styles: `
    .empty-msg {
      padding: 1rem;
      color: rgba(0, 0, 0, 0.5);
      text-align: center;
    }
  `
})
export class BreakListComponent {
  @Input() breaks: Break[] = [];
  @Output() delete = new EventEmitter<string>();
}
