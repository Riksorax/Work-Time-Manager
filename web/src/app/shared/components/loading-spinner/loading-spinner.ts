import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';

@Component({
  selector: 'app-loading-spinner',
  standalone: true,
  imports: [CommonModule, MatProgressSpinnerModule],
  template: `
    <div class="spinner-container">
      <mat-spinner [diameter]="diameter"></mat-spinner>
      @if (message) {
        <p>{{ message }}</p>
      }
    </div>
  `,
  styles: `
    .spinner-container {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 2rem;
      width: 100%;
    }
    p {
      margin-top: 1rem;
      color: rgba(0, 0, 0, 0.6);
    }
  `
})
export class LoadingSpinnerComponent {
  @Input() message?: string;
  @Input() diameter: number = 40;
}
