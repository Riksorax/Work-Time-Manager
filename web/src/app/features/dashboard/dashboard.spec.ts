import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { DashboardComponent } from './dashboard';
import { DashboardService } from './dashboard.service';
import { LeaveBalanceService } from '../../core/services/leave-balance';

describe('DashboardComponent.goToSettings', () => {
  it('navigiert zu /settings', () => {
    const navigate = vi.fn();
    TestBed.overrideComponent(DashboardComponent, { set: { template: '', imports: [] } });
    TestBed.configureTestingModule({
      providers: [
        { provide: DashboardService, useValue: {} },
        { provide: LeaveBalanceService, useValue: {} },
        { provide: Router, useValue: { navigate } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: {} },
        { provide: TranslateService, useValue: {} },
      ],
    });
    TestBed.createComponent(DashboardComponent).componentInstance.goToSettings();
    expect(navigate).toHaveBeenCalledWith(['/settings']);
  });
});
