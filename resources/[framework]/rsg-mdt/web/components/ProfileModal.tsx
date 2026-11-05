import { useState, useEffect, useCallback } from 'react';
import { fetchNui, useNuiEvent } from '../hooks/useNui';
import type { Citizen, IssuedCharge, JailConfig, JailStatus } from '../types';
import { IssueChargesModal } from './IssueChargesModal';
import { CriminalRecordList } from './CriminalRecordList';
import { ChargeDetailModal } from './ChargeDetailModal';
import { FinesPanel } from './FinesPanel';

interface ProfileModalProps {
  citizen: Citizen;
  onClose: () => void;
  onIssueWarrant?: (citizenid: string, name: string) => void;
  onChargesIssued?: () => void;
  onViewReport?: (reportId: number) => void;
  targetPlayerId?: number;
}

export function ProfileModal({ citizen, onClose, onIssueWarrant, onChargesIssued, onViewReport, targetPlayerId }: ProfileModalProps) {
  const [editingPicture, setEditingPicture] = useState(false);
  const [pictureUrl, setPictureUrl] = useState('');
  const [savingPicture, setSavingPicture] = useState(false);
  const [showChargeModal, setShowChargeModal] = useState(false);
  const [charges, setCharges] = useState<IssuedCharge[]>([]);
  const [loadingCharges, setLoadingCharges] = useState(true);
  const [selectedCharge, setSelectedCharge] = useState<IssuedCharge | null>(null);
  const [jailMinutes, setJailMinutes] = useState(5);
  const [jailStatus, setJailStatus] = useState<JailStatus>({ status: 'idle' });
  const [jailConfig, setJailConfig] = useState<JailConfig | null>(null);

  const fetchCharges = useCallback(async () => {
    setLoadingCharges(true);
    const result = await fetchNui<IssuedCharge[]>('getIssuedCharges', { citizenid: citizen.citizenid }, []);
    setCharges(result || []);
    setLoadingCharges(false);
  }, [citizen.citizenid]);

  useEffect(() => {
    fetchCharges();
    const loadJailConfig = async () => {
      const config = await fetchNui<JailConfig>('getJailConfig', {}, {
        delaySeconds: 5,
        maxDistance: 10.0,
        jailCoords: { x: 0, y: 0, z: 0 },
        jailHeading: 0,
        enabled: true,
        minutesPerMonth: 1,
        maxJailDistance: 100.0
      });
      setJailConfig(config);
    };
    loadJailConfig();
  }, [fetchCharges]);

  useNuiEvent<{ citizenid: string }>('chargesUpdated', (data) => {
    if (data && data.citizenid === citizen.citizenid) {
      fetchCharges();
    }
  });

  useNuiEvent<JailStatus>('jailStatus', (data) => {
    setJailStatus(data);
  });

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (selectedCharge) {
          setSelectedCharge(null);
        } else if (showChargeModal) {
          setShowChargeModal(false);
        } else {
          onClose();
        }
      }
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [onClose, selectedCharge, showChargeModal]);

  const handleSavePicture = async () => {
    if (savingPicture) return;
    setSavingPicture(true);
    
    const result = await fetchNui<{ success: boolean }>('setProfilePicture', {
      citizenid: citizen.citizenid,
      url: pictureUrl || null,
    }, { success: true });
    
    if (result.success) {
      citizen.profilePicture = pictureUrl || null;
      setEditingPicture(false);
      setPictureUrl('');
    }
    setSavingPicture(false);
  };

  const handleChargesIssued = () => {
    setShowChargeModal(false);
    fetchCharges();
    onChargesIssued?.();
  };

  const handleJailPlayer = async () => {
    if (jailStatus.status === 'processing') return;
    
    setJailStatus({ status: 'processing', remaining: jailConfig?.delaySeconds || 5 });
    
    const result = await fetchNui<{ success: boolean; message: string; delaySeconds?: number }>('startJailProcess', {
      citizenid: citizen.citizenid,
      minutes: jailMinutes,
      targetPlayerId: targetPlayerId
    }, { success: true, message: 'Jail process started', delaySeconds: 5 });
    
    if (!result.success) {
      setJailStatus({ status: 'failed', message: result.message });
    }
  };

  const isJailProcessing = jailStatus.status === 'processing';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center" onClick={onClose}>
      <div className="absolute inset-0 bg-black/70" />
      <div 
        className="relative bg-zinc-900 border border-zinc-700 rounded-xl w-full max-w-4xl max-h-[85vh] overflow-hidden shadow-2xl"
        onClick={e => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-zinc-800">
          <h3 className="text-white text-xl font-bold" style={{ fontFamily: 'var(--font-display)' }}>
            Citizen Profile
          </h3>
          <button onClick={onClose} className="text-zinc-400 hover:text-white transition-colors">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="p-6 overflow-y-auto max-h-[calc(85vh-80px)]">
          <div className="flex gap-8">
            <div className="flex-shrink-0">
              <div className="relative w-40 h-40 bg-zinc-800 border-2 border-zinc-700 rounded-lg overflow-hidden">
                {citizen.profilePicture ? (
                  <img
                    src={citizen.profilePicture}
                    alt="Profile"
                    className="w-full h-full object-cover"
                    onError={(e) => {
                      (e.target as HTMLImageElement).src = '';
                      (e.target as HTMLImageElement).style.display = 'none';
                    }}
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center">
                    <svg className="w-20 h-20 text-zinc-600" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
                    </svg>
                  </div>
                )}
              </div>
              
              {!editingPicture ? (
                <button
                  onClick={() => {
                    setEditingPicture(true);
                    setPictureUrl(citizen.profilePicture || '');
                  }}
                  className="mt-3 w-full text-sm text-zinc-400 hover:text-amber-400 transition-colors"
                >
                  {citizen.profilePicture ? 'Change Photo' : 'Add Photo'}
                </button>
              ) : (
                <div className="mt-3 space-y-2">
                  <input
                    type="url"
                    placeholder="Image URL..."
                    value={pictureUrl}
                    onChange={(e) => setPictureUrl(e.target.value)}
                    className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-sm text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
                  />
                  <div className="flex gap-2">
                    <button
                      onClick={handleSavePicture}
                      disabled={savingPicture}
                      className="flex-1 bg-amber-600 hover:bg-amber-500 disabled:bg-zinc-700 rounded px-3 py-1.5 text-sm text-white transition-colors"
                    >
                      {savingPicture ? 'Saving...' : 'Save'}
                    </button>
                    <button
                      onClick={() => {
                        setEditingPicture(false);
                        setPictureUrl('');
                      }}
                      className="flex-1 bg-zinc-700 hover:bg-zinc-600 rounded px-3 py-1.5 text-sm text-white transition-colors"
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              )}
            </div>

            <div className="flex-1 min-w-0">
              <div className="flex items-start justify-between mb-6">
                <div>
                  <h4 className="text-2xl font-bold text-white">
                    {citizen.charinfo?.firstname} {citizen.charinfo?.lastname}
                  </h4>
                  <p className="text-amber-400 text-sm mt-1">{citizen.citizenid}</p>
                </div>
<div className="flex items-center gap-3">
                   {citizen.isWanted && (
                     <span className="flex items-center gap-1.5 bg-red-600/20 text-red-400 border border-red-600/30 px-3 py-1.5 rounded-lg text-sm font-medium">
                       <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                         <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                       </svg>
                       WANTED
                     </span>
                   )}
                   {onIssueWarrant && !citizen.isWanted && (
                     <button
                       onClick={() => onIssueWarrant(citizen.citizenid, `${citizen.charinfo?.firstname} ${citizen.charinfo?.lastname}`)}
                       className="bg-red-600 hover:bg-red-500 px-4 py-2 rounded-lg text-white text-sm font-medium transition-colors"
                     >
                       Issue Warrant
                     </button>
                   )}
                   <button
                     onClick={() => setShowChargeModal(true)}
                     className="bg-amber-600 hover:bg-amber-500 px-4 py-2 rounded-lg text-white text-sm font-medium transition-colors"
                   >
                     Issue Charges
                   </button>
                   {jailConfig?.enabled && targetPlayerId && (
                     <div className="flex items-center gap-2">
                       <input
                         type="number"
                         min={1}
                         max={999}
                         value={jailMinutes}
                         onChange={(e) => setJailMinutes(Math.max(1, parseInt(e.target.value) || 1))}
                         disabled={isJailProcessing}
                         className="w-16 bg-zinc-800 border border-zinc-700 rounded px-2 py-2 text-sm text-white text-center focus:outline-none focus:border-amber-600 disabled:opacity-50"
                       />
                       <span className="text-zinc-400 text-sm">min</span>
                       <div className="relative group">
                         <button
                           onClick={handleJailPlayer}
                           disabled={isJailProcessing}
                           className={`px-4 py-2 rounded-lg text-white text-sm font-medium transition-colors flex items-center gap-2 ${
                             isJailProcessing 
                               ? 'bg-zinc-700 cursor-not-allowed' 
                               : 'bg-orange-600 hover:bg-orange-500'
                           }`}
                         >
                           {isJailProcessing ? (
                             <>
                               <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                                 <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"/>
                                 <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
                               </svg>
                               <span>{jailStatus.remaining}s</span>
                             </>
                           ) : (
                             'Jail'
                           )}
                         </button>
                         {isJailProcessing && (
                           <div className="absolute bottom-full mb-2 right-0 bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-xs text-zinc-300 whitespace-nowrap">
                             Processing... Stay within {jailConfig.maxDistance}m of target
                           </div>
                         )}
                       </div>
                     </div>
                   )}
                 </div>
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div className="bg-zinc-800/50 rounded-lg p-3">
                  <p className="text-zinc-500 text-xs uppercase tracking-wider mb-1">Gender</p>
                  <p className="text-white">{citizen.charinfo?.gender === 0 ? 'Male' : 'Female'}</p>
                </div>
                <div className="bg-zinc-800/50 rounded-lg p-3">
                  <p className="text-zinc-500 text-xs uppercase tracking-wider mb-1">Birthdate</p>
                  <p className="text-white">{citizen.charinfo?.birthdate || 'Unknown'}</p>
                </div>
                <div className="bg-zinc-800/50 rounded-lg p-3">
                  <p className="text-zinc-500 text-xs uppercase tracking-wider mb-1">Job</p>
                  <p className="text-white">{citizen.job?.label || 'Unemployed'}</p>
                </div>
              </div>

              <div className="mt-6">
                 <h5 className="text-zinc-400 text-sm font-bold mb-3 uppercase tracking-wider flex items-center gap-2">
                   <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                     <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                   </svg>
                   Criminal Records
                 </h5>
                 <CriminalRecordList
                   charges={charges}
                   loading={loadingCharges}
                   onChargeClick={setSelectedCharge}
                   onRefresh={fetchCharges}
                 />
               </div>

               <div className="mt-6">
                 <FinesPanel citizenid={citizen.citizenid} />
               </div>
            </div>
          </div>
        </div>
      </div>

      {showChargeModal && (
        <IssueChargesModal
          citizenid={citizen.citizenid}
          citizenName={`${citizen.charinfo?.firstname} ${citizen.charinfo?.lastname}`}
          onClose={() => setShowChargeModal(false)}
          onIssued={handleChargesIssued}
          targetPlayerId={targetPlayerId}
        />
      )}

      {selectedCharge && (
        <ChargeDetailModal
          charge={selectedCharge}
          onClose={() => setSelectedCharge(null)}
          onViewReport={onViewReport}
        />
      )}
    </div>
  );
}
