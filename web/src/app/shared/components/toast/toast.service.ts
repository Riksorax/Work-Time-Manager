import { Injectable, inject } from '@angular/core';
import { MatSnackBar, MatSnackBarConfig } from '@angular/material/snack-bar';

@Injectable({ providedIn: 'root' })
export class ToastService {
  private snackBar = inject(MatSnackBar);

  private readonly base: MatSnackBarConfig = {
    duration: 3500,
    horizontalPosition: 'right',
    verticalPosition: 'bottom',
  };

  success(message: string): void {
    this.snackBar.open(message, '✕', {
      ...this.base,
      panelClass: ['toast-success'],
    });
  }

  error(message: string): void {
    this.snackBar.open(message, '✕', {
      ...this.base,
      duration: 6000,
      panelClass: ['toast-error'],
    });
  }

  info(message: string): void {
    this.snackBar.open(message, '✕', {
      ...this.base,
      panelClass: ['toast-info'],
    });
  }
}
