import { Injectable, inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';

@Injectable({
  providedIn: 'root'
})
export class ToastService {
  private snackBar = inject(MatSnackBar);

  success(message: string): void {
    this.snackBar.open(message, 'OK', {
      duration: 3000,
      panelClass: ['success-snackbar']
    });
  }

  error(message: string): void {
    this.snackBar.open(message, 'OK', {
      duration: 5000,
      panelClass: ['error-snackbar']
    });
  }

  info(message: string): void {
    this.snackBar.open(message, 'OK', {
      duration: 3000
    });
  }
}
