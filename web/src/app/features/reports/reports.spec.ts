import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { ReportsComponent } from './reports';
import { ReportsService } from './reports.service';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { WebPremiumService } from '../../core/services/web-premium';

describe('ReportsComponent.goToSettings', () => {
  it('navigiert zu /settings', () => {
    const navigate = vi.fn();
    TestBed.overrideComponent(ReportsComponent, { set: { template: '', imports: [] } });
    TestBed.configureTestingModule({
      providers: [
        { provide: ReportsService, useValue: {} },
        { provide: LeaveBalanceService, useValue: {} },
        { provide: Router, useValue: { navigate } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: {} },
        { provide: TranslateService, useValue: {} },
        { provide: WebPremiumService, useValue: {
          isRestoring: signal(false), isPurchasing: signal(false), isConfigured: signal(false) } },
      ],
    });
    TestBed.createComponent(ReportsComponent).componentInstance.goToSettings();
    expect(navigate).toHaveBeenCalledWith(['/settings']);
  });
});
