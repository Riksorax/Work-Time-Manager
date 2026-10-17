import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';
import { AuthService } from './auth';
import { DataSyncService } from '../services/data-sync';
import { LoginComponent } from './login';

describe('LoginComponent: Logo (#437)', () => {
  let fixture: ComponentFixture<LoginComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [LoginComponent],
      providers: [
        provideRouter([]),
        { provide: AuthService, useValue: { signInWithGoogle: vi.fn() } },
        { provide: DataSyncService, useValue: { syncAll: vi.fn() } },
        { provide: MatSnackBar, useValue: { open: vi.fn() } },
      ],
    }).compileComponents();
    fixture = TestBed.createComponent(LoginComponent);
    fixture.detectChanges();
  });

  it('zeigt das Logo als dekoratives Bild (alt="") statt des schedule-Icons', () => {
    const wrapper = fixture.nativeElement.querySelector('.logo-wrapper') as HTMLElement;
    const img = wrapper.querySelector('img.logo-icon') as HTMLImageElement;
    expect(img).not.toBeNull();
    expect(img.getAttribute('alt')).toBe('');
    expect(img.getAttribute('src')).toContain('logo.svg');
    expect(wrapper.querySelector('mat-icon')).toBeNull();
  });

  it('behält den Titel als zugänglichen Namen neben dem Logo', () => {
    expect(fixture.nativeElement.querySelector('h1').textContent).toContain('Work Time Manager');
  });
});
