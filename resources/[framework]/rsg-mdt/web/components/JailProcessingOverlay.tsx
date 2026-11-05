import { useEffect, useState } from 'react';
import type { JailStatus, JailConfig } from '../types';

interface JailProcessingOverlayProps {
  status: JailStatus;
  config: JailConfig | null;
  citizenName: string;
  onAbort: () => void;
  onComplete?: () => void;
}

export function JailProcessingOverlay({
  status,
  config,
  citizenName,
  onAbort,
  onComplete,
}: JailProcessingOverlayProps) {
  const [displayTime, setDisplayTime] = useState(status.remaining || 0);

  useEffect(() => {
    if (status.status === 'processing' && status.remaining !== undefined) {
      setDisplayTime(status.remaining);
    }
  }, [status]);

  useEffect(() => {
    if (status.status === 'completed') {
      const timer = setTimeout(() => {
        onComplete?.();
      }, 1500);
      return () => clearTimeout(timer);
    }
  }, [status.status, onComplete]);

  if (status.status === 'idle') return null;

  const isProcessing = status.status === 'processing';
  const isCompleted = status.status === 'completed';
  const isFailed = status.status === 'failed';
  const isCancelled = status.status === 'cancelled';

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center">
      <div className="absolute inset-0 bg-black/80" />
      <div className="relative bg-zinc-900 border border-zinc-700 rounded-2xl w-full max-w-md p-8 shadow-2xl">
        <div className="text-center">
          {isProcessing && (
            <>
              <div className="mb-6">
                <div className="relative w-32 h-32 mx-auto">
                  <svg className="w-32 h-32 transform -rotate-90" viewBox="0 0 100 100">
                    <circle
                      className="text-zinc-800"
                      strokeWidth="8"
                      stroke="currentColor"
                      fill="transparent"
                      r="42"
                      cx="50"
                      cy="50"
                    />
                    <circle
                      className="text-orange-500 transition-all duration-1000"
                      strokeWidth="8"
                      strokeLinecap="round"
                      stroke="currentColor"
                      fill="transparent"
                      r="42"
                      cx="50"
                      cy="50"
                      strokeDasharray={`${(displayTime / (config?.delaySeconds || 5)) * 264} 264`}
                    />
                  </svg>
                  <div className="absolute inset-0 flex items-center justify-center">
                    <span className="text-5xl font-bold text-white" style={{ fontFamily: 'var(--font-display)' }}>
                      {displayTime}
                    </span>
                  </div>
                </div>
              </div>

              <h3 className="text-xl font-bold text-white mb-2" style={{ fontFamily: 'var(--font-display)' }}>
                Processing Sentencing
              </h3>
              <p className="text-zinc-400 mb-2">
                Jailing <span className="text-amber-400 font-medium">{citizenName}</span>
              </p>
              <p className="text-orange-400 text-sm mb-6 flex items-center justify-center gap-2">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
                Stay within {config?.maxDistance}m of suspect
              </p>

              <button
                onClick={onAbort}
                className="w-full bg-red-600 hover:bg-red-500 text-white font-bold py-3 px-6 rounded-xl transition-colors flex items-center justify-center gap-2"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
                Abort Sentencing
              </button>
            </>
          )}

          {isCompleted && (
            <>
              <div className="w-20 h-20 mx-auto mb-6 rounded-full bg-green-600/20 flex items-center justify-center">
                <svg className="w-10 h-10 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-green-400 mb-2" style={{ fontFamily: 'var(--font-display)' }}>
                Sentencing Complete
              </h3>
              <p className="text-zinc-400 mb-1">
                <span className="text-white font-medium">{citizenName}</span> has been sent to jail
              </p>
              {status.jailed && status.totalJailtime !== undefined && (
                <p className="text-zinc-500 text-sm">
                  Total: {status.totalJailtime} months ({status.totalJailtime * (config?.minutesPerMonth || 1)} minutes)
                </p>
              )}
              <p className="text-zinc-600 text-xs mt-4">Closing MDT...</p>
            </>
          )}

          {isFailed && (
            <>
              <div className="w-20 h-20 mx-auto mb-6 rounded-full bg-red-600/20 flex items-center justify-center">
                <svg className="w-10 h-10 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-red-400 mb-2" style={{ fontFamily: 'var(--font-display)' }}>
                Sentencing Failed
              </h3>
              <p className="text-zinc-400 mb-6">{status.message || 'An error occurred during processing'}</p>
              <button
                onClick={onAbort}
                className="w-full bg-zinc-700 hover:bg-zinc-600 text-white font-medium py-3 px-6 rounded-xl transition-colors"
              >
                Close
              </button>
            </>
          )}

          {isCancelled && (
            <>
              <div className="w-20 h-20 mx-auto mb-6 rounded-full bg-amber-600/20 flex items-center justify-center">
                <svg className="w-10 h-10 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-amber-400 mb-2" style={{ fontFamily: 'var(--font-display)' }}>
                Sentencing Cancelled
              </h3>
              <p className="text-zinc-400 mb-6">{status.message || 'Sentencing was cancelled'}</p>
              <button
                onClick={onAbort}
                className="w-full bg-zinc-700 hover:bg-zinc-600 text-white font-medium py-3 px-6 rounded-xl transition-colors"
              >
                Close
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
