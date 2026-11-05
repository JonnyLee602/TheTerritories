import { useState, useCallback, useEffect } from 'react';
import { isDebug, useNuiEvent, fetchNui } from './hooks/useNui';
import type { Officer, Stats, JailStatus, JailConfig } from './types';
import { Window } from './components/Window';
import { Sidebar } from './components/Sidebar';
import { Dashboard } from './pages/Dashboard';
import { CitizenLookup } from './pages/CitizenLookup';
import { CriminalRecords } from './pages/CriminalRecords';
import { Warrants } from './pages/Warrants';
import { Bolos } from './pages/Bolos';
import { Reports } from './pages/Reports';
import { StaffManagement } from './pages/StaffManagement';
import { JailProcessingOverlay } from './components/JailProcessingOverlay';

type Page = 'dashboard' | 'citizens' | 'records' | 'warrants' | 'bolos' | 'reports' | 'staff';

interface WarrantPrefill {
  citizenid: string;
  name: string;
}

interface WindowConfig {
  width?: number;
  height?: number;
  x?: number;
  y?: number;
}

interface Permissions {
  canCreateRecords?: boolean;
  canDeleteRecords?: boolean;
  canManageWarrants?: boolean;
  isAdmin?: boolean;
}

export default function App() {
  const [visible, setVisible] = useState(isDebug);
  const [currentPage, setCurrentPage] = useState<Page>('dashboard');
  const [officer, setOfficer] = useState<Officer | null>(null);
  const [permissions, setPermissions] = useState<Permissions | null>(null);
  const [stats, setStats] = useState<Stats | null>(null);
  const [windowConfig, setWindowConfig] = useState<WindowConfig>({});
  const [warrantPrefill, setWarrantPrefill] = useState<WarrantPrefill | null>(null);
  const [viewingReportId, setViewingReportId] = useState<number | null>(null);
  const [viewingChargeId, setViewingChargeId] = useState<number | null>(null);
  const [jailStatus, setJailStatus] = useState<JailStatus>({ status: 'idle' });
  const [jailConfig, setJailConfig] = useState<JailConfig | null>(null);

  useNuiEvent<Officer & { permissions?: Permissions; window?: WindowConfig }>('open', (data) => {
    setOfficer(data);
    if (data.permissions) {
      setPermissions(data.permissions);
    }
    if (data.window) {
      setWindowConfig(data.window);
    }
    setVisible(true);
  });

  useNuiEvent('close', () => setVisible(false));

  useNuiEvent<JailStatus>('jailStatus', (data) => {
    setJailStatus(data);
    if (data.status === 'completed') {
      setTimeout(() => {
        setVisible(false);
        fetchNui('close', {}, { success: true });
        setJailStatus({ status: 'idle' });
      }, 1500);
    }
    if (data.status === 'failed' || data.status === 'cancelled') {
      setTimeout(() => {
        setJailStatus({ status: 'idle' });
      }, 3000);
    }
  });

  useEffect(() => {
    if (visible) {
      fetchNui<JailConfig>('getJailConfig', {}, {
        delaySeconds: 5,
        maxDistance: 10.0,
        jailCoords: { x: 0, y: 0, z: 0 },
        jailHeading: 0,
        enabled: true,
        minutesPerMonth: 1,
        maxJailDistance: 100.0
      }).then(setJailConfig);
    }
  }, [visible]);

  const handleAbortJail = useCallback(async () => {
    await fetchNui('abortJail', {}, { success: true });
    setJailStatus({ status: 'idle' });
  }, []);

  const handleClose = useCallback(() => {
    setVisible(false);
    fetchNui('close', {}, { success: true });
  }, []);

  const refreshStats = useCallback(async () => {
    const s = await fetchNui<Stats>('getStats', {}, {
      records: 12,
      activeWarrants: 3,
      activeBolos: 2,
      reports: 8,
      unpaidFines: 5
    });
    setStats(s);
  }, []);

  useEffect(() => {
    if (visible) refreshStats();
  }, [visible, refreshStats]);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') handleClose();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [handleClose]);

  if (!visible) return null;

  return (
    <div className="fixed inset-0" style={{ background: 'rgba(0, 0, 0, 0.5)' }}>
      <Window
        title="Law Enforcement Records"
        initialWidth={windowConfig.width ?? 1300}
        initialHeight={windowConfig.height ?? 850}
        minWidth={1100}
        minHeight={600}
        onClose={handleClose}
      >
        {/* Sidebar */}
        <Sidebar
          officer={officer}
          currentPage={currentPage}
          onPageChange={setCurrentPage}
          isAdmin={permissions?.isAdmin}
        />

        {/* Main Content */}
        <div className="flex-1 overflow-auto p-6" style={{ background: 'linear-gradient(180deg, #111113 0%, #0a0a0b 100%)' }}>
          <div className="max-w-5xl mx-auto">
            {currentPage === 'dashboard' && <Dashboard stats={stats} officer={officer} onPageChange={setCurrentPage} />}
            {currentPage === 'citizens' && (
              <CitizenLookup 
                onIssueWarrant={(citizenid, name) => {
                  setWarrantPrefill({ citizenid, name });
                  setCurrentPage('warrants');
                }}
                onViewReport={(reportId) => {
                  setViewingReportId(reportId);
                  setCurrentPage('reports');
                }}
              />
            )}
            {currentPage === 'records' && (
              <CriminalRecords 
                viewingChargeId={viewingChargeId}
                onViewReport={(reportId) => {
                  setViewingReportId(reportId);
                  setCurrentPage('reports');
                }}
                onChargeViewed={() => setViewingChargeId(null)}
              />
            )}
            {currentPage === 'warrants' && <Warrants onRefresh={refreshStats} prefill={warrantPrefill} onClearPrefill={() => setWarrantPrefill(null)} />}
            {currentPage === 'bolos' && <Bolos onRefresh={refreshStats} />}
            {currentPage === 'reports' && (
              <Reports 
                onRefresh={refreshStats}
                viewingReportId={viewingReportId}
                onViewCharge={(chargeId) => {
                  setViewingChargeId(chargeId);
                  setCurrentPage('records');
                }}
                onReportViewed={() => setViewingReportId(null)}
              />
            )}
            {currentPage === 'staff' && permissions?.isAdmin && <StaffManagement />}
          </div>
        </div>
      </Window>

      <JailProcessingOverlay
        status={jailStatus}
        config={jailConfig}
        citizenName={jailStatus.citizenName || 'Suspect'}
        onAbort={handleAbortJail}
      />
    </div>
  );
}
